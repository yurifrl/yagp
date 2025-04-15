const std = @import("std");
const rl = @import("raylib");
const debugger = @import("debugger.zig");
const camera_mod = @import("camera.zig");

// Re-export Camera for backwards compatibility
pub const Camera = camera_mod.Camera;

// Entity Types
pub const Entity = struct {
    id: u64,
};

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Renderable = struct {
    color: rl.Color,
    width: f32,
    height: f32,
    shape: enum { Rectangle, Circle, Texture },
    texture_id: ?u32 = null,
};

// ECS System
pub const ArchetypeId = u64;

pub const Archetype = struct {
    id: ArchetypeId,
    entities: std.ArrayList(Entity),
    positions: std.ArrayList(Position),
    renderables: std.ArrayList(?Renderable),
    cameras: std.ArrayList(?Camera),
    entityToIndex: std.AutoHashMap(u64, usize),

    pub fn init(allocator: std.mem.Allocator, id: ArchetypeId) Archetype {
        return Archetype{
            .id = id,
            .entities = std.ArrayList(Entity).init(allocator),
            .positions = std.ArrayList(Position).init(allocator),
            .renderables = std.ArrayList(?Renderable).init(allocator),
            .cameras = std.ArrayList(?Camera).init(allocator),
            .entityToIndex = std.AutoHashMap(u64, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Archetype) void {
        self.entities.deinit();
        self.positions.deinit();
        self.renderables.deinit();
        self.cameras.deinit();
        self.entityToIndex.deinit();
    }

    pub fn addEntity(self: *Archetype, entity: Entity, position: Position, renderable: Renderable) !void {
        const index = self.entities.items.len;
        try self.entityToIndex.put(entity.id, index);
        try self.entities.append(entity);
        try self.positions.append(position);
        try self.renderables.append(renderable);
        try self.cameras.append(null);
    }

    pub fn addCamera(self: *Archetype, entity: Entity, camera: Camera) !void {
        if (self.getEntityIndex(entity.id)) |entity_index| {
            self.cameras.items[entity_index] = camera;
        }
    }

    pub fn getEntityIndex(self: Archetype, entity_id: u64) ?usize {
        return self.entityToIndex.get(entity_id);
    }
};

// Chunking System
pub const ChunkCoord = struct {
    x: i32,
    y: i32,
};

pub const Chunk = struct {
    coord: ChunkCoord,
    entities: std.ArrayList(Entity),

    pub fn init(allocator: std.mem.Allocator, coord: ChunkCoord) Chunk {
        return Chunk{
            .coord = coord,
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.entities.deinit();
    }

    pub fn iterEntities(self: Chunk) []const Entity {
        return self.entities.items;
    }
};

// Consolidated World with chunking
pub const ChunkedWorld = struct {
    archetypes: std.ArrayList(Archetype),
    entityToArchetype: std.AutoHashMap(u64, usize),
    chunks: std.AutoHashMap(ChunkCoord, Chunk),
    chunk_size: i32,
    allocator: std.mem.Allocator,
    camera_entity: Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !ChunkedWorld {
        var chunked_world = ChunkedWorld{
            .archetypes = std.ArrayList(Archetype).init(allocator),
            .entityToArchetype = std.AutoHashMap(u64, usize).init(allocator),
            .chunks = std.AutoHashMap(ChunkCoord, Chunk).init(allocator),
            .chunk_size = chunk_size,
            .allocator = allocator,
            .camera_entity = Entity{ .id = 0 },
        };

        // Create default camera
        chunked_world.camera_entity = try chunked_world.createDefaultCamera();

        return chunked_world;
    }

    pub fn deinit(self: *ChunkedWorld) void {
        for (self.archetypes.items) |*archetype| {
            archetype.deinit();
        }
        self.archetypes.deinit();
        self.entityToArchetype.deinit();

        var iter = self.chunks.valueIterator();
        while (iter.next()) |chunk| {
            chunk.deinit();
        }

        self.chunks.deinit();
    }

    pub fn createDefaultCamera(self: *ChunkedWorld) !Entity {
        const position = Position{ .x = 0, .y = 0 };
        const offset = rl.Vector2{ .x = 0, .y = 0 };
        const zoom = 1.0;
        const camera_entity = try self.createEntity(
            position,
            Renderable{
                .color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .width = 0,
                .height = 0,
                .shape = .Rectangle,
            },
        );
        const camera_component = camera_mod.Camera{
            .offset = offset,
            .target = rl.Vector2{ .x = position.x, .y = position.y },
            .rotation = 0,
            .zoom = zoom,
            .is_dragging = false,
            .drag_start = rl.Vector2{ .x = 0, .y = 0 },
        };

        try self.addCamera(camera_entity, camera_component);
        return camera_entity;
    }

    pub fn getChunkCoord(self: ChunkedWorld, pos: Position) ChunkCoord {
        return ChunkCoord{
            .x = @divFloor(@as(i32, @intFromFloat(pos.x)), self.chunk_size),
            .y = @divFloor(@as(i32, @intFromFloat(pos.y)), self.chunk_size),
        };
    }

    pub fn getOrCreateChunk(self: *ChunkedWorld, coord: ChunkCoord) !*Chunk {
        const result = try self.chunks.getOrPut(coord);
        if (!result.found_existing) {
            result.value_ptr.* = Chunk.init(self.allocator, coord);
        }
        return result.value_ptr;
    }

    pub fn assignToChunk(self: *ChunkedWorld, entity: Entity, pos: Position) !void {
        const coord = self.getChunkCoord(pos);
        const chunk = try self.getOrCreateChunk(coord);
        try chunk.entities.append(entity);
    }

    pub fn createEntity(self: *ChunkedWorld, position: Position, renderable: Renderable) !Entity {
        const entity = Entity{ .id = std.crypto.random.int(u64) };

        // Add entity to the archetype-based system
        if (self.archetypes.items.len == 0) {
            const archetype = Archetype.init(self.allocator, 1);
            try self.archetypes.append(archetype);
        }

        const archetype_index = 0;
        try self.archetypes.items[archetype_index].addEntity(entity, position, renderable);
        try self.entityToArchetype.put(entity.id, archetype_index);

        // Assign to chunk based on position
        try self.assignToChunk(entity, position);

        return entity;
    }

    pub fn addCamera(self: *ChunkedWorld, entity: Entity, camera: Camera) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            try self.archetypes.items[archetype_index].addCamera(entity, camera);
        }
    }

    pub fn getComponent(self: ChunkedWorld, comptime T: type, entity: Entity) ?T {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                return switch (T) {
                    Position => archetype.positions.items[entity_index],
                    Renderable => archetype.renderables.items[entity_index],
                    Camera => archetype.cameras.items[entity_index],
                    else => @compileError("Unsupported component type"),
                };
            }
        }
        return null;
    }

    pub fn setComponent(self: *ChunkedWorld, comptime T: type, entity: Entity, component: T) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                switch (T) {
                    Position => archetype.positions.items[entity_index] = component,
                    Renderable => archetype.renderables.items[entity_index] = component,
                    Camera => archetype.cameras.items[entity_index] = component,
                    else => @compileError("Unsupported component type"),
                }
            }
        }
    }

    pub fn getVisibleChunks(self: ChunkedWorld, camera_entity: Entity) !struct { top_left: rl.Vector2, bottom_right: rl.Vector2, visible_chunks: std.ArrayList(ChunkCoord) } {
        var result = std.ArrayList(ChunkCoord).init(self.allocator);

        const camera_comp = self.getComponent(Camera, camera_entity) orelse return error.CameraNotFound;

        // Get screen bounds in world coordinates
        const screen_width = rl.getScreenWidth();
        const screen_height = rl.getScreenHeight();
        const top_left = rl.getScreenToWorld2D(.{ .x = 0, .y = 0 }, camera_comp.toRaylib());
        const bottom_right = rl.getScreenToWorld2D(.{ .x = @floatFromInt(screen_width), .y = @floatFromInt(screen_height) }, camera_comp.toRaylib());

        // Calculate chunk grid boundaries
        const start_chunk_x = @divFloor(@as(i32, @intFromFloat(top_left.x)), self.chunk_size);
        const end_chunk_x = @divFloor(@as(i32, @intFromFloat(bottom_right.x)), self.chunk_size) + 1;
        const start_chunk_y = @divFloor(@as(i32, @intFromFloat(top_left.y)), self.chunk_size);
        const end_chunk_y = @divFloor(@as(i32, @intFromFloat(bottom_right.y)), self.chunk_size) + 1;

        // Collect all chunks in the visible area
        var y = start_chunk_y;
        while (y <= end_chunk_y) : (y += 1) {
            var x = start_chunk_x;
            while (x <= end_chunk_x) : (x += 1) {
                const coord = ChunkCoord{ .x = x, .y = y };
                try result.append(coord);
            }
        }

        return .{
            .top_left = top_left,
            .bottom_right = bottom_right,
            .visible_chunks = result,
        };
    }

    pub fn isChunkVisible(self: ChunkedWorld, chunk_coord: ChunkCoord, top_left: rl.Vector2, bottom_right: rl.Vector2) bool {
        const chunk_size_f: f32 = @floatFromInt(self.chunk_size);
        const chunk_world_x = @as(f32, @floatFromInt(chunk_coord.x * self.chunk_size));
        const chunk_world_y = @as(f32, @floatFromInt(chunk_coord.y * self.chunk_size));

        return !(chunk_world_x + chunk_size_f < top_left.x or
            chunk_world_x > bottom_right.x or
            chunk_world_y + chunk_size_f < top_left.y or
            chunk_world_y > bottom_right.y);
    }

    pub fn getComponentOrError(self: ChunkedWorld, comptime T: type, entity: Entity) !T {
        return self.getComponent(T, entity) orelse error.ComponentNotFound;
    }

    pub fn withComponents(self: ChunkedWorld, entity: Entity, comptime callback: anytype) error{ComponentNotFound}!void {
        // Get entity archetype and index directly
        const archetype_index = self.entityToArchetype.get(entity.id) orelse return error.ComponentNotFound;
        const archetype = &self.archetypes.items[archetype_index];
        const entity_index = archetype.getEntityIndex(entity.id) orelse return error.ComponentNotFound;

        const position = archetype.positions.items[entity_index];
        const renderable = archetype.renderables.items[entity_index] orelse return error.ComponentNotFound;
        const camera = archetype.cameras.items[entity_index];

        return callback(position, renderable, camera);
    }
};
