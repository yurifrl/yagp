const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const ui = @import("ui.zig");

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
var inspector: ?*ui.Inspector = null;
var allocator_instance: std.mem.Allocator = undefined;
const MAX_MESSAGES = 15;
const MESSAGE_LIFETIME = 5.0; // seconds before complete fade
const FADE_START = 3.0; // seconds before starting to fade

pub fn init(allocator: std.mem.Allocator) void {
    if (!initialized) {
        allocator_instance = allocator;
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

        if (inspector) |insp| {
            insp.deinit();
            allocator_instance.destroy(insp);
            inspector = null;
        }

        initialized = false;
    }
}

// Initialize the inspector window
pub fn initInspector(x: i32, y: i32, width: i32, height: i32) !void {
    if (!initialized) return error.DebuggerNotInitialized;

    if (inspector != null) {
        // Already initialized
        return;
    }

    const insp = try allocator_instance.create(ui.Inspector);
    insp.* = ui.Inspector.init(allocator_instance, "World Inspector", x, y, width, height);
    inspector = insp;
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

    // Also render the inspector if it exists
    if (inspector) |insp| {
        insp.render();
    }
}

// Update inspector with current entity data
pub fn updateInspector(g: *game.Game) !void {
    if (!initialized) return error.DebuggerNotInitialized;
    if (inspector == null) return error.InspectorNotInitialized;

    var insp = inspector.?;

    // Clear all nodes first
    insp.nodes.clearRetainingCapacity();

    // Create or refresh entities node
    const entities_node = try insp.addNode("Entities");

    // Get all entities from game
    var chunk_iter = g.chunked_world.chunks.iterator();
    while (chunk_iter.next()) |entry| {
        const chunk = entry.value_ptr.*;

        for (chunk.iterEntities()) |entity| {
            // Use a fixed buffer for entity ID to avoid allocation failures
            var entity_id_buf: [32]u8 = undefined;
            const entity_str = std.fmt.bufPrintZ(&entity_id_buf, "Entity {d}", .{entity.id}) catch "Entity";
            const entity_node = try entities_node.addChild(entity_str);

            // Add position component if exists
            if (g.chunked_world.getComponent(game.Position, entity)) |pos| {
                const pos_node = try entity_node.addChild("Position");

                var pos_buf: [64]u8 = undefined;
                const pos_str = std.fmt.bufPrintZ(&pos_buf, "x: {d:.1}, y: {d:.1}", .{ pos.x, pos.y }) catch "x, y";
                _ = try pos_node.addChild(pos_str);
            }

            // Add renderable component if exists
            if (g.chunked_world.getComponent(game.Renderable, entity)) |rend| {
                const rend_node = try entity_node.addChild("Renderable");

                var color_buf: [128]u8 = undefined;
                const color_str = std.fmt.bufPrintZ(&color_buf, "color: rgba({d},{d},{d},{d})", .{ rend.color.r, rend.color.g, rend.color.b, rend.color.a }) catch "color";
                _ = try rend_node.addChild(color_str);

                var size_buf: [64]u8 = undefined;
                const size_str = std.fmt.bufPrintZ(&size_buf, "size: {d:.1}x{d:.1}", .{ rend.width, rend.height }) catch "size";
                _ = try rend_node.addChild(size_str);

                var shape_buf: [64]u8 = undefined;
                const shape_str = std.fmt.bufPrintZ(&shape_buf, "shape: {s}", .{@tagName(rend.shape)}) catch "shape";
                _ = try rend_node.addChild(shape_str);
            }
        }
    }
}
