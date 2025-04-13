const std = @import("std");
const rl = @import("raylib");

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

pub const Camera = struct {
    offset: rl.Vector2,
    target: rl.Vector2,
    rotation: f32,
    zoom: f32,
    is_dragging: bool,
    drag_start: rl.Vector2,
};

const ArchetypeId = u64;

const Archetype = struct {
    id: ArchetypeId,
    entities: std.ArrayList(Entity),
    positions: std.ArrayList(Position),
    renderables: std.ArrayList(Renderable),
    cameras: std.ArrayList(Camera),

    pub fn init(allocator: std.mem.Allocator, id: ArchetypeId) Archetype {
        return Archetype{
            .id = id,
            .entities = std.ArrayList(Entity).init(allocator),
            .positions = std.ArrayList(Position).init(allocator),
            .renderables = std.ArrayList(Renderable).init(allocator),
            .cameras = std.ArrayList(Camera).init(allocator),
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

        const empty_camera = Camera{
            .offset = rl.Vector2{ .x = 0, .y = 0 },
            .target = rl.Vector2{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = 1.0,
            .is_dragging = false,
            .drag_start = rl.Vector2{ .x = 0, .y = 0 },
        };
        try self.cameras.append(empty_camera);
    }

    pub fn addCamera(self: *Archetype, entity: Entity) !void {
        if (self.getEntityIndex(entity.id)) |entity_index| {
            self.cameras.items[entity_index] = Camera{
                .offset = rl.Vector2{ .x = 0, .y = 0 },
                .target = rl.Vector2{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1.0,
                .is_dragging = false,
                .drag_start = rl.Vector2{ .x = 0, .y = 0 },
            };
        }
    }

    pub fn getEntityIndex(self: Archetype, entity_id: u64) ?usize {
        for (self.entities.items, 0..) |e, i| {
            if (e.id == entity_id) return i;
        }
        return null;
    }
};

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

    pub fn setComponent(self: *World, comptime T: type, entity: Entity, component: T) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                switch (T) {
                    Position => archetype.positions.items[entity_index] = component,
                    Camera => archetype.cameras.items[entity_index] = component,
                    Renderable => archetype.renderables.items[entity_index] = component,
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
