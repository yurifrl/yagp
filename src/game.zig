const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs.zig");
const debugger = @import("debugger.zig");
const camera = @import("camera.zig");

// Re-export core types for backwards compatibility
pub const Entity = ecs.Entity;
pub const Position = ecs.Position;
pub const Renderable = ecs.Renderable;
pub const Camera = ecs.Camera;

// Rendering function
pub fn renderChunkedWorld(world: ecs.ChunkedWorld) void {
    // Get camera from world
    const camera_component = world.getComponent(ecs.Camera, world.camera_entity) orelse return;

    // Begin 2D mode with camera
    rl.beginMode2D(camera_component.toRaylib());
    defer rl.endMode2D();

    // Calculate visible area
    const chunk_size_f: f32 = @floatFromInt(world.chunk_size);

    // Get screen bounds in world coordinates
    const screen_width = rl.getScreenWidth();
    const screen_height = rl.getScreenHeight();
    const top_left = rl.getScreenToWorld2D(.{ .x = 0, .y = 0 }, camera_component.toRaylib());
    const bottom_right = rl.getScreenToWorld2D(.{ .x = @floatFromInt(screen_width), .y = @floatFromInt(screen_height) }, camera_component.toRaylib());

    // Calculate chunk grid boundaries
    const start_x = @divFloor(@as(i32, @intFromFloat(top_left.x)), world.chunk_size) * world.chunk_size;
    const end_x = @divFloor(@as(i32, @intFromFloat(bottom_right.x)), world.chunk_size) * world.chunk_size + world.chunk_size * 2;
    const start_y = @divFloor(@as(i32, @intFromFloat(top_left.y)), world.chunk_size) * world.chunk_size;
    const end_y = @divFloor(@as(i32, @intFromFloat(bottom_right.y)), world.chunk_size) * world.chunk_size + world.chunk_size * 2;

    // Draw grid
    const grid_color = rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 };

    // Draw vertical grid lines
    var x = @as(f32, @floatFromInt(start_x));
    while (x < @as(f32, @floatFromInt(end_x))) : (x += chunk_size_f) {
        rl.drawLine(@intFromFloat(x), @intFromFloat(@as(f32, @floatFromInt(start_y))), @intFromFloat(x), @intFromFloat(@as(f32, @floatFromInt(end_y))), grid_color);
    }

    // Draw horizontal grid lines
    var y = @as(f32, @floatFromInt(start_y));
    while (y < @as(f32, @floatFromInt(end_y))) : (y += chunk_size_f) {
        rl.drawLine(@intFromFloat(@as(f32, @floatFromInt(start_x))), @intFromFloat(y), @intFromFloat(@as(f32, @floatFromInt(end_x))), @intFromFloat(y), grid_color);
    }

    // Draw each chunk with its entities
    const chunk_coord_color = rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };
    var chunk_iter = world.chunks.iterator();
    while (chunk_iter.next()) |entry| {
        const chunk = entry.value_ptr.*;

        // Calculate chunk position in world coordinates
        const chunk_world_x = @as(f32, @floatFromInt(chunk.coord.x * world.chunk_size));
        const chunk_world_y = @as(f32, @floatFromInt(chunk.coord.y * world.chunk_size));

        // Skip chunks outside of visible area
        if (chunk_world_x + chunk_size_f < top_left.x or
            chunk_world_x > bottom_right.x or
            chunk_world_y + chunk_size_f < top_left.y or
            chunk_world_y > bottom_right.y)
        {
            continue;
        }

        // Render chunk coordinate in the center of the chunk
        const chunk_center_x = chunk_world_x + (chunk_size_f / 2);
        const chunk_center_y = chunk_world_y + (chunk_size_f / 2);

        const coord_text = std.fmt.allocPrintZ(world.allocator, "({}, {})", .{ chunk.coord.x, chunk.coord.y }) catch continue;
        defer world.allocator.free(coord_text);

        rl.drawText(coord_text, @intFromFloat(chunk_center_x - 20), @intFromFloat(chunk_center_y), 12, chunk_coord_color);

        // Draw entities in this chunk
        for (chunk.iterEntities()) |entity| {
            const position = world.getComponent(ecs.Position, entity) orelse continue;
            const renderable = world.getComponent(ecs.Renderable, entity) orelse continue;

            switch (renderable.shape) {
                .Rectangle => {
                    rl.drawRectangle(@intFromFloat(position.x), @intFromFloat(position.y), @intFromFloat(renderable.width), @intFromFloat(renderable.height), renderable.color);
                },
                .Circle => {
                    rl.drawCircle(@intFromFloat(position.x), @intFromFloat(position.y), renderable.width / 2, renderable.color);
                },
                .Texture => {
                    // Texture rendering would go here if implemented
                },
            }
        }
    }
}

// Game functions
pub const Game = struct {
    chunked_world: ecs.ChunkedWorld,
    camera_entity: ecs.Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !Game {
        const chunked_world = try ecs.ChunkedWorld.init(allocator, chunk_size);

        return Game{
            .chunked_world = chunked_world,
            .camera_entity = chunked_world.camera_entity,
        };
    }

    pub fn deinit(self: *Game) void {
        self.chunked_world.deinit();
    }

    pub fn createEntity(self: *Game, position: ecs.Position, renderable: ecs.Renderable) !ecs.Entity {
        return try self.chunked_world.createEntity(position, renderable);
    }

    pub fn update(self: *Game) !void {
        try camera.updateSystem(&self.chunked_world, self.camera_entity);

        // Log visible chunks when L key is pressed
        if (rl.isKeyPressed(.l)) {
            debugger.logVisibleChunks(self.chunked_world, self.camera_entity);
        }
    }

    pub fn render(self: Game) void {
        renderChunkedWorld(self.chunked_world);
    }
};
