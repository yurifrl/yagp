const std = @import("std");
const rl = @import("raylib");
const debugger = @import("debugger.zig");
const camera = @import("camera.zig");
const ecs = @import("ecs.zig");

// Re-export core types for backwards compatibility
pub const Entity = ecs.Entity;
pub const Position = ecs.Position;
pub const Renderable = ecs.Renderable;
pub const Camera = ecs.Camera;

// Game combines the chunked world and game functionalities
pub const Game = struct {
    entity_manager: ecs.EntityManager,
    chunks: std.AutoHashMap(ecs.ChunkCoord, ecs.Chunk),
    chunk_size: i32,
    allocator: std.mem.Allocator,
    camera_component: camera.Camera,
    camera_entity: Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !Game {
        const entity_manager = ecs.EntityManager.init(allocator);
        const initial_camera_position = Position{ .x = 0, .y = 0 };
        const camera_component = camera.Camera.init(initial_camera_position.toRaylib());

        var game = Game{
            .entity_manager = entity_manager,
            .chunks = std.AutoHashMap(ecs.ChunkCoord, ecs.Chunk).init(allocator),
            .chunk_size = chunk_size,
            .allocator = allocator,
            .camera_entity = Entity{ .id = 0 },
            .camera_component = camera_component,
        };

        // Create default camera
        game.camera_entity = try game.createEntity(
            initial_camera_position,
            Renderable{
                .color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .width = 0,
                .height = 0,
                .shape = .Rectangle,
            },
        );

        return game;
    }

    pub fn deinit(self: *Game) void {
        self.entity_manager.deinit();

        var iter = self.chunks.valueIterator();
        while (iter.next()) |chunk| {
            chunk.deinit();
        }

        self.chunks.deinit();
    }

    pub fn createEntity(self: *Game, position: Position, renderable: Renderable) !Entity {
        const entity = try self.entity_manager.createEntity();

        try self.entity_manager.upsertComponent(entity, position);
        try self.entity_manager.upsertComponent(entity, renderable);

        // Calculate chunk coordinates from position
        const coord = ecs.ChunkCoord{
            .x = @divFloor(@as(i32, @intFromFloat(position.x)), self.chunk_size),
            .y = @divFloor(@as(i32, @intFromFloat(position.y)), self.chunk_size),
        };

        // Get or create the chunk
        const result = try self.chunks.getOrPut(coord);
        if (!result.found_existing) {
            result.value_ptr.* = ecs.Chunk.init(self.allocator, coord);
        }

        // Add entity to chunk
        try result.value_ptr.entities.append(entity);

        return entity;
    }

    pub fn renderWorld(self: *Game) !void {
        camera.updateSystem(&self.camera_component);
        // Update the component in the world with our local copy
        try self.entity_manager.upsertComponent(self.camera_entity, self.camera_component);

        // Begin 2D mode with camera
        rl.beginMode2D(self.camera_component.toRaylib());
        defer rl.endMode2D();

        // Get visible chunks
        var visible_chunks = std.ArrayList(ecs.ChunkCoord).init(self.allocator);
        defer visible_chunks.deinit();

        // Get screen bounds in world coordinates
        const bounds = camera.getScreenBoundsWorld(self.camera_component, rl.getScreenWidth(), rl.getScreenHeight());

        // Calculate chunk grid boundaries
        const start_chunk_x = @divFloor(@as(i32, @intFromFloat(bounds.top_left.x)), self.chunk_size);
        const end_chunk_x = @divFloor(@as(i32, @intFromFloat(bounds.bottom_right.x)), self.chunk_size) + 1;
        const start_chunk_y = @divFloor(@as(i32, @intFromFloat(bounds.top_left.y)), self.chunk_size);
        const end_chunk_y = @divFloor(@as(i32, @intFromFloat(bounds.bottom_right.y)), self.chunk_size) + 1;

        // Collect all chunks in the visible area
        var y = start_chunk_y;
        while (y <= end_chunk_y) : (y += 1) {
            var x = start_chunk_x;
            while (x <= end_chunk_x) : (x += 1) {
                const coord = ecs.ChunkCoord{ .x = x, .y = y };
                try visible_chunks.append(coord);
            }
        }

        // Render grid
        debugger.renderChunkGrid(bounds.top_left, bounds.bottom_right, self.chunk_size);

        // Iterate only over visible chunks
        for (visible_chunks.items) |coord| {
            if (self.chunks.get(coord)) |chunk| {
                // Render entities in this chunk
                for (chunk.iterEntities()) |entity| {
                    const position = self.entity_manager.getComponent(Position, entity) orelse continue;
                    const renderable = self.entity_manager.getComponent(Renderable, entity) orelse continue;

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
    }
};
