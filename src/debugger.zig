const std = @import("std");
const rl = @import("raylib");

// Debug message with timestamp and fade info
const DebugMessage = struct {
    text: []const u8,
    timestamp: f64,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, text: []const u8) !DebugMessage {
        const copied_text = try allocator.dupe(u8, text);
        return DebugMessage{
            .text = copied_text,
            .timestamp = rl.getTime(),
            .allocator = allocator,
        };
    }

    fn deinit(self: *const DebugMessage) void {
        self.allocator.free(self.text);
    }
};

// Global debugger state
var messages = std.ArrayList(DebugMessage).init(std.heap.page_allocator);
var initialized = false;
const MAX_MESSAGES = 15;
const MESSAGE_LIFETIME = 5.0; // seconds before complete fade
const FADE_START = 3.0; // seconds before starting to fade

pub fn init(allocator: std.mem.Allocator) void {
    if (!initialized) {
        messages = std.ArrayList(DebugMessage).init(allocator);
        initialized = true;
    }
}

pub fn deinit() void {
    if (initialized) {
        for (messages.items) |*message| {
            message.deinit();
        }
        messages.deinit();
        initialized = false;
    }
}

// Add a new debug message
pub fn log(text: []const u8) void {
    if (!initialized) return;

    const allocator = messages.allocator;
    const message = DebugMessage.init(allocator, text) catch return;

    // Add new message
    messages.append(message) catch {
        message.deinit();
        return;
    };

    // Limit number of messages
    while (messages.items.len > MAX_MESSAGES) {
        if (messages.items.len > 0) {
            var old_message = messages.orderedRemove(0);
            old_message.deinit();
        }
    }
}

// Format and log with arguments like std.debug.print
pub fn logFmt(comptime fmt: []const u8, args: anytype) void {
    if (!initialized) return;

    const allocator = messages.allocator;
    const text = std.fmt.allocPrint(allocator, fmt, args) catch return;

    log(text);
    allocator.free(text);
}

// Update and render debug messages
pub fn render() void {
    if (!initialized) return;

    const current_time = rl.getTime();

    // Console background - smaller and green with opacity
    const console_width: f32 = 200;
    const console_y: f32 = 10;
    const console_x = 10; // Positioned on the left side

    rl.drawRectangle(@intFromFloat(console_x), @intFromFloat(console_y), @intFromFloat(console_width), 250, rl.Color{ .r = 0, .g = 120, .b = 0, .a = 100 });

    // Messages
    var y: f32 = console_y + 10;
    var i: usize = 0;
    while (i < messages.items.len) {
        const message = messages.items[i];
        const age = current_time - message.timestamp;

        // Remove old messages
        if (age > MESSAGE_LIFETIME) {
            var old_message = messages.orderedRemove(i);
            old_message.deinit();
            continue;
        }

        // Calculate alpha based on age
        var alpha: u8 = 255;
        if (age > FADE_START) {
            const fade_percentage = 1.0 - ((age - FADE_START) / (MESSAGE_LIFETIME - FADE_START));
            alpha = @intFromFloat(fade_percentage * 255);
        }

        // Convert to null-terminated string slice
        const text_z = std.mem.span(@as([*:0]const u8, @ptrCast(message.text)));

        // Draw message
        rl.drawText(text_z, @intFromFloat(console_x + 10), @intFromFloat(y), 9, rl.Color{ .r = 200, .g = 255, .b = 200, .a = alpha });

        y += 14;
        i += 1;
    }
}

// Log chunks currently in view
pub fn logVisibleChunks(chunked_world: @import("ecs.zig").ChunkedWorld, camera_entity: @import("ecs.zig").Entity) void {
    if (!initialized) return;

    // Get camera component
    const camera_opt = chunked_world.getComponent(@import("ecs.zig").Camera, camera_entity);
    if (camera_opt == null) return;
    const camera = camera_opt.?;

    // Use camera's toRaylib method
    const rl_camera = camera.toRaylib();

    // Calculate visible area in world coordinates
    const screen_width = rl.getScreenWidth();
    const screen_height = rl.getScreenHeight();

    const top_left = rl.getScreenToWorld2D(rl.Vector2{ .x = 0, .y = 0 }, rl_camera);
    const bottom_right = rl.getScreenToWorld2D(rl.Vector2{ .x = @floatFromInt(screen_width), .y = @floatFromInt(screen_height) }, rl_camera);

    // Calculate chunk grid boundaries
    const start_x = @divFloor(@as(i32, @intFromFloat(top_left.x)), chunked_world.chunk_size);
    const end_x = @divFloor(@as(i32, @intFromFloat(bottom_right.x)), chunked_world.chunk_size) + 1;
    const start_y = @divFloor(@as(i32, @intFromFloat(top_left.y)), chunked_world.chunk_size);
    const end_y = @divFloor(@as(i32, @intFromFloat(bottom_right.y)), chunked_world.chunk_size) + 1;

    // Count visible chunks
    var visible_count: usize = 0;
    var existing_count: usize = 0;

    // Check each potentially visible chunk
    var y = start_y;
    while (y <= end_y) : (y += 1) {
        var x = start_x;
        while (x <= end_x) : (x += 1) {
            const coord = @import("ecs.zig").ChunkCoord{ .x = x, .y = y };
            visible_count += 1;

            if (chunked_world.chunks.contains(coord)) {
                existing_count += 1;
            }
        }
    }

    logFmt("Visible chunks: {d} ({d} loaded) from ({}, {}) to ({}, {})", .{ visible_count, existing_count, start_x, start_y, end_x, end_y });
}
