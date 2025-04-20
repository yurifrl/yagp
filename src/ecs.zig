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
    pub fn toRaylib(self: Position) rl.Vector2 {
        return .{ .x = self.x, .y = self.y };
    }
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

    pub fn upsertComponent(self: *EntityManager, entity: Entity, component: anytype) !void {
        const T = @TypeOf(component);
        const type_name = @typeName(T);

        if (!self.component_storages.contains(type_name)) {
            var storage_ptr = try self.allocator.create(ComponentStorage(T));
            storage_ptr.* = ComponentStorage(T).init(self.allocator);
            try self.component_storages.put(type_name, storage_ptr.interface());
        }

        const storage = self.component_storages.get(type_name).?;
        storage.remove(entity.id);
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
