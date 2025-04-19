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
        const camera_component = chunked_world.getComponent(Camera, camera_entity) orelse return error.CameraNotFound;

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

        // Update the component in the world with our local copy
        try self.chunked_world.setComponent(Camera, self.camera_entity, self.camera_component);
    }

    pub fn render(self: Game) !void {
        try self.renderWorld();
    }

    fn renderWorld(self: Game) !void {
        // Begin 2D mode with camera
        rl.beginMode2D(self.camera_component.toRaylib());
        defer rl.endMode2D();

        // Get screen dimensions
        const screen_width = rl.getScreenWidth();
        const screen_height = rl.getScreenHeight();

        // Get visible chunks using the utility function
        const visibility_result = try self.chunked_world.getVisibleChunks(self.camera_entity, screen_width, screen_height);
        defer visibility_result.visible_chunks.deinit();

        // Render grid
        debugger.renderChunkGrid(visibility_result.top_left, visibility_result.bottom_right, self.chunked_world.chunk_size);

        // Iterate only over visible chunks
        for (visibility_result.visible_chunks.items) |coord| {
            if (self.chunked_world.chunks.get(coord)) |chunk| {
                renderEntities(self.chunked_world, chunk);
            }
        }
    }
};

fn renderEntities(world: ecs.ChunkedWorld, chunk: ecs.Chunk) void {
    for (chunk.iterEntities()) |entity| {
        const position = world.entity_manager.getComponent(ecs.Position, entity) orelse continue;
        const renderable = world.entity_manager.getComponent(ecs.Renderable, entity) orelse continue;

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
