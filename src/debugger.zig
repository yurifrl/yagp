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
