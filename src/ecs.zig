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

// Chunking System
pub const ChunkCoord = struct {
    x: i32,
    y: i32,
};

pub const VisibleChunksData = struct {
    top_left: rl.Vector2,
    bottom_right: rl.Vector2,
    visible_chunks: std.ArrayList(ChunkCoord),
};

// Component storage interface with type erasure
pub const ComponentStorageInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        get: *const fn (ptr: *anyopaque, entity_id: u64) ?*anyopaque,
        set: *const fn (ptr: *anyopaque, entity_id: u64, component_ptr: *const anyopaque) anyerror!void,
        remove: *const fn (ptr: *anyopaque, entity_id: u64) void,
    };

    pub fn deinit(self: ComponentStorageInterface) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn get(self: ComponentStorageInterface, entity_id: u64) ?*anyopaque {
        return self.vtable.get(self.ptr, entity_id);
    }

    pub fn set(self: ComponentStorageInterface, entity_id: u64, component_ptr: *const anyopaque) !void {
        return self.vtable.set(self.ptr, entity_id, component_ptr);
    }

    pub fn remove(self: ComponentStorageInterface, entity_id: u64) void {
        self.vtable.remove(self.ptr, entity_id);
    }
};

// Type-specific component storage implementation
pub fn ComponentStorage(comptime T: type) type {
    return struct {
        const Self = @This();
        data: std.AutoHashMap(u64, T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = std.AutoHashMap(u64, T).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn interface(self: *Self) ComponentStorageInterface {
            return .{
                .ptr = self,
                .vtable = &.{
                    .deinit = deinitFn,
                    .get = getFn,
                    .set = setFn,
                    .remove = removeFn,
                },
            };
        }

        fn deinitFn(ptr: *anyopaque) void {
            const self = @as(*Self, @ptrCast(@alignCast(ptr)));
            self.deinit();
        }

        fn getFn(ptr: *anyopaque, entity_id: u64) ?*anyopaque {
            const self = @as(*Self, @ptrCast(@alignCast(ptr)));
            if (self.data.getPtr(entity_id)) |component| {
                return component;
            }
            return null;
        }

        fn setFn(ptr: *anyopaque, entity_id: u64, component_ptr: *const anyopaque) !void {
            const self = @as(*Self, @ptrCast(@alignCast(ptr)));
            const component = @as(*const T, @ptrCast(@alignCast(component_ptr))).*;
            try self.data.put(entity_id, component);
        }

        fn removeFn(ptr: *anyopaque, entity_id: u64) void {
            const self = @as(*Self, @ptrCast(@alignCast(ptr)));
            _ = self.data.remove(entity_id);
        }
    };
}

// Entity Manager
pub const EntityManager = struct {
    allocator: std.mem.Allocator,
    entities: std.AutoHashMap(u64, Entity),
    component_storages: std.StringHashMap(ComponentStorageInterface),
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator) EntityManager {
        return .{
            .allocator = allocator,
            .entities = std.AutoHashMap(u64, Entity).init(allocator),
            .component_storages = std.StringHashMap(ComponentStorageInterface).init(allocator),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *EntityManager) void {
        var storage_iter = self.component_storages.valueIterator();
        while (storage_iter.next()) |storage| {
            storage.deinit();
        }
        self.component_storages.deinit();
        self.entities.deinit();
    }

    pub fn createEntity(self: *EntityManager) !Entity {
        const entity = Entity{ .id = self.next_id };
        try self.entities.put(entity.id, entity);
        self.next_id += 1;
        return entity;
    }

    pub fn addComponent(self: *EntityManager, entity: Entity, component: anytype) !void {
        const T = @TypeOf(component);
        const type_name = @typeName(T);

        if (!self.component_storages.contains(type_name)) {
            var storage_ptr = try self.allocator.create(ComponentStorage(T));
            storage_ptr.* = ComponentStorage(T).init(self.allocator);
            try self.component_storages.put(type_name, storage_ptr.interface());
        }

        const storage = self.component_storages.get(type_name).?;
        try storage.set(entity.id, &component);
    }

    pub fn getComponent(self: EntityManager, comptime T: type, entity: Entity) ?T {
        const type_name = @typeName(T);
        if (self.component_storages.get(type_name)) |storage| {
            if (storage.get(entity.id)) |ptr| {
                return @as(*T, @ptrCast(@alignCast(ptr))).*;
            }
        }
        return null;
    }

    pub fn setComponent(self: *EntityManager, entity: Entity, component: anytype) !void {
        const T = @TypeOf(component);
        const type_name = @typeName(T);

        if (!self.component_storages.contains(type_name)) {
            try self.addComponent(entity, component);
            return;
        }

        const storage = self.component_storages.get(type_name).?;
        storage.remove(entity.id);
        try storage.set(entity.id, &component);
    }

    pub fn removeEntity(self: *EntityManager, entity: Entity) void {
        var storage_iter = self.component_storages.valueIterator();
        while (storage_iter.next()) |storage| {
            storage.remove(entity.id);
        }
        _ = self.entities.remove(entity.id);
    }
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
    entity_manager: EntityManager,
    chunks: std.AutoHashMap(ChunkCoord, Chunk),
    chunk_size: i32,
    allocator: std.mem.Allocator,
    camera_entity: Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !ChunkedWorld {
        const entity_manager = EntityManager.init(allocator);

        var chunked_world = ChunkedWorld{
            .entity_manager = entity_manager,
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
        self.entity_manager.deinit();

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

        try self.entity_manager.addComponent(camera_entity, camera_component);
        return camera_entity;
    }

    pub fn createEntity(self: *ChunkedWorld, position: Position, renderable: Renderable) !Entity {
        const entity = try self.entity_manager.createEntity();

        try self.entity_manager.addComponent(entity, position);
        try self.entity_manager.addComponent(entity, renderable);

        // Calculate chunk coordinates from position
        const coord = ChunkCoord{
            .x = @divFloor(@as(i32, @intFromFloat(position.x)), self.chunk_size),
            .y = @divFloor(@as(i32, @intFromFloat(position.y)), self.chunk_size),
        };

        // Get or create the chunk
        const result = try self.chunks.getOrPut(coord);
        if (!result.found_existing) {
            result.value_ptr.* = Chunk.init(self.allocator, coord);
        }

        // Add entity to chunk
        try result.value_ptr.entities.append(entity);

        return entity;
    }

    pub fn getComponent(self: ChunkedWorld, comptime T: type, entity: Entity) ?T {
        return self.entity_manager.getComponent(T, entity);
    }

    pub fn setComponent(self: *ChunkedWorld, comptime T: type, entity: Entity, component: T) !void {
        try self.entity_manager.setComponent(entity, component);

        // Update chunk assignment if this is a position component
        if (T == Position) {
            // TODO: Handle moving entities between chunks when their position changes
            // This would require removing from current chunk and adding to new chunk
        }
    }

    pub fn getVisibleChunks(self: ChunkedWorld, camera_entity: Entity, screen_width: i32, screen_height: i32) !VisibleChunksData {
        var result = std.ArrayList(ChunkCoord).init(self.allocator);
        const camera_comp = self.entity_manager.getComponent(Camera, camera_entity) orelse return error.CameraNotFound;

        // Get screen bounds in world coordinates
        const bounds = camera_mod.getScreenBoundsWorld(camera_comp, screen_width, screen_height);

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
                const coord = ChunkCoord{ .x = x, .y = y };
                try result.append(coord);
            }
        }

        return .{
            .top_left = bounds.top_left,
            .bottom_right = bounds.bottom_right,
            .visible_chunks = result,
        };
    }
};
