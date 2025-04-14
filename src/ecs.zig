const std = @import("std");
const rl = @import("raylib");
const debugger = @import("debugger.zig");

// Entity Types
pub const Entity = struct {
    id: u64,
};

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Camera = struct {
    offset: rl.Vector2,
    target: rl.Vector2,
    rotation: f32,
    zoom: f32,
    is_dragging: bool,
    drag_start: rl.Vector2,

    pub fn toRaylib(self: Camera) rl.Camera2D {
        return .{
            .offset = self.offset,
            .target = self.target,
            .rotation = self.rotation,
            .zoom = self.zoom,
        };
    }
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

    pub fn init(allocator: std.mem.Allocator, id: ArchetypeId) Archetype {
        return Archetype{
            .id = id,
            .entities = std.ArrayList(Entity).init(allocator),
            .positions = std.ArrayList(Position).init(allocator),
            .renderables = std.ArrayList(?Renderable).init(allocator),
            .cameras = std.ArrayList(?Camera).init(allocator),
        };
    }

    pub fn deinit(self: *Archetype) void {
        self.entities.deinit();
        self.positions.deinit();
        self.renderables.deinit();
        self.cameras.deinit();
    }

    pub fn addEntity(self: *Archetype, entity: Entity, position: Position, renderable: Renderable) !void {
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
        for (self.entities.items, 0..) |e, i| {
            if (e.id == entity_id) return i;
        }
        return null;
    }
};

// World with pure component storage
pub const World = struct {
    archetypes: std.ArrayList(Archetype),
    entityToArchetype: std.AutoHashMap(u64, usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return World{
            .archetypes = std.ArrayList(Archetype).init(allocator),
            .entityToArchetype = std.AutoHashMap(u64, usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        for (self.archetypes.items) |*archetype| {
            archetype.deinit();
        }
        self.archetypes.deinit();
        self.entityToArchetype.deinit();
    }

    pub fn createEntity(self: *World, entity: Entity, position: Position, renderable: Renderable) !void {
        if (self.archetypes.items.len == 0) {
            const archetype = Archetype.init(self.allocator, 1);
            try self.archetypes.append(archetype);
        }

        const archetype_index = 0;
        try self.archetypes.items[archetype_index].addEntity(entity, position, renderable);
        try self.entityToArchetype.put(entity.id, archetype_index);
    }

    pub fn addCamera(self: *World, entity: Entity, camera: Camera) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            try self.archetypes.items[archetype_index].addCamera(entity, camera);
        }
    }

    pub fn setComponent(self: *World, comptime T: type, entity: Entity, component: T) !void {
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

    pub fn getComponent(self: World, comptime T: type, entity: Entity) ?T {
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
};

// Chunked World without raylib dependencies
pub const ChunkedWorld = struct {
    world: World,
    chunks: std.AutoHashMap(ChunkCoord, Chunk),
    chunk_size: i32,
    allocator: std.mem.Allocator,
    camera_entity: Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !ChunkedWorld {
        var chunked_world = ChunkedWorld{
            .world = World.init(allocator),
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
        self.world.deinit();

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
        const camera_component = Camera{
            .offset = offset,
            .target = rl.Vector2{ .x = position.x, .y = position.y },
            .rotation = 0,
            .zoom = zoom,
            .is_dragging = false,
            .drag_start = rl.Vector2{ .x = 0, .y = 0 },
        };

        try self.world.addCamera(camera_entity, camera_component);
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

        // Add entity to the archetype-based world
        try self.world.createEntity(entity, position, renderable);

        // Assign to chunk based on position
        try self.assignToChunk(entity, position);

        return entity;
    }
};
