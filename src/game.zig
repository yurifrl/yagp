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

// Game functions
pub const Game = struct {
    chunked_world: ecs.ChunkedWorld,
    camera_entity: ecs.Entity,
    camera_component: Camera,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !Game {
        const chunked_world = try ecs.ChunkedWorld.init(allocator, chunk_size);
        const camera_entity = chunked_world.camera_entity;
        const camera_component = chunked_world.getComponent(Camera, camera_entity) orelse {
            return error.CameraNotFound;
        };

        return Game{
            .chunked_world = chunked_world,
            .camera_entity = camera_entity,
            .camera_component = camera_component,
        };
    }

    pub fn deinit(self: *Game) void {
        self.chunked_world.deinit();
    }

    pub fn createEntity(self: *Game, position: ecs.Position, renderable: ecs.Renderable) !ecs.Entity {
        return try self.chunked_world.createEntity(position, renderable);
    }

    pub fn update(self: *Game) !void {
        camera.updateSystem(&self.camera_component);

        // Log visible chunks when L key is pressed
        if (rl.isKeyPressed(.l)) {
            debugger.logVisibleChunks(self.chunked_world, self.camera_entity);
        }

        // Update the component in the world with our local copy
        try self.chunked_world.setComponent(Camera, self.camera_entity, self.camera_component);
    }

    pub fn render(self: Game) void {
        self.renderWorld();
    }

    fn renderWorld(self: Game) void {
        // Begin 2D mode with camera
        rl.beginMode2D(self.camera_component.toRaylib());
        defer rl.endMode2D();

        // Calculate visible area
        const chunk_size_f: f32 = @floatFromInt(self.chunked_world.chunk_size);

        // Get screen bounds in world coordinates
        const screen_width = rl.getScreenWidth();
        const screen_height = rl.getScreenHeight();
        const top_left = rl.getScreenToWorld2D(.{ .x = 0, .y = 0 }, self.camera_component.toRaylib());
        const bottom_right = rl.getScreenToWorld2D(.{ .x = @floatFromInt(screen_width), .y = @floatFromInt(screen_height) }, self.camera_component.toRaylib());

        // Calculate chunk grid boundaries
        const start_x = @divFloor(@as(i32, @intFromFloat(top_left.x)), self.chunked_world.chunk_size) * self.chunked_world.chunk_size;
        const end_x = @divFloor(@as(i32, @intFromFloat(bottom_right.x)), self.chunked_world.chunk_size) * self.chunked_world.chunk_size + self.chunked_world.chunk_size * 2;
        const start_y = @divFloor(@as(i32, @intFromFloat(top_left.y)), self.chunked_world.chunk_size) * self.chunked_world.chunk_size;
        const end_y = @divFloor(@as(i32, @intFromFloat(bottom_right.y)), self.chunked_world.chunk_size) * self.chunked_world.chunk_size + self.chunked_world.chunk_size * 2;

        renderGrid(start_x, end_x, start_y, end_y, chunk_size_f);
        self.renderChunks(top_left, bottom_right, chunk_size_f);
    }

    fn renderChunks(self: Game, top_left: rl.Vector2, bottom_right: rl.Vector2, chunk_size_f: f32) void {
        const chunk_coord_color = rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };
        var chunk_iter = self.chunked_world.chunks.iterator();
        while (chunk_iter.next()) |entry| {
            const chunk = entry.value_ptr.*;

            // Calculate chunk position in world coordinates
            const chunk_world_x = @as(f32, @floatFromInt(chunk.coord.x * self.chunked_world.chunk_size));
            const chunk_world_y = @as(f32, @floatFromInt(chunk.coord.y * self.chunked_world.chunk_size));

            // Skip chunks outside of visible area
            if (chunk_world_x + chunk_size_f < top_left.x or
                chunk_world_x > bottom_right.x or
                chunk_world_y + chunk_size_f < top_left.y or
                chunk_world_y > bottom_right.y)
            {
                continue;
            }

            self.renderChunkCoordinates(chunk, chunk_world_x, chunk_world_y, chunk_size_f, chunk_coord_color);
            renderEntities(self.chunked_world, chunk);
        }
    }

    fn renderChunkCoordinates(self: Game, chunk: ecs.Chunk, chunk_world_x: f32, chunk_world_y: f32, chunk_size_f: f32, coord_color: rl.Color) void {
        // Render chunk coordinate in the center of the chunk
        const chunk_center_x = chunk_world_x + (chunk_size_f / 2);
        const chunk_center_y = chunk_world_y + (chunk_size_f / 2);

        const coord_text = std.fmt.allocPrintZ(self.chunked_world.allocator, "({}, {})", .{ chunk.coord.x, chunk.coord.y }) catch return;
        defer self.chunked_world.allocator.free(coord_text);

        rl.drawText(coord_text, @intFromFloat(chunk_center_x - 20), @intFromFloat(chunk_center_y), 12, coord_color);
    }
};

fn renderGrid(start_x: i32, end_x: i32, start_y: i32, end_y: i32, chunk_size_f: f32) void {
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
}

fn renderEntities(world: ecs.ChunkedWorld, chunk: ecs.Chunk) void {
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
