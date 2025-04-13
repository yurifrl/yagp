const std = @import("std");
const rl = @import("raylib");

// Entity and Component Types
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

// ECS System
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

pub const ChunkedWorld = struct {
    world: World,
    chunks: std.AutoHashMap(ChunkCoord, Chunk),
    chunk_size: i32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) ChunkedWorld {
        return ChunkedWorld{
            .world = World.init(allocator),
            .chunks = std.AutoHashMap(ChunkCoord, Chunk).init(allocator),
            .chunk_size = chunk_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ChunkedWorld) void {
        self.world.deinit();

        var iter = self.chunks.valueIterator();
        while (iter.next()) |chunk| {
            chunk.deinit();
        }

        self.chunks.deinit();
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

    pub fn setEntityPosition(self: *ChunkedWorld, entity: Entity, pos: Position) !void {
        // Remove from old chunk if exists
        if (self.world.getComponent(Position, entity)) |old_pos| {
            const old_coord = self.getChunkCoord(old_pos);
            if (self.chunks.getPtr(old_coord)) |chunk| {
                // Find and remove entity from old chunk
                for (chunk.entities.items, 0..) |e, i| {
                    if (e.id == entity.id) {
                        _ = chunk.entities.orderedRemove(i);
                        break;
                    }
                }
            }
        }

        // Update position in world
        try self.world.setComponent(Position, entity, pos);

        // Add to new chunk
        try self.assignToChunk(entity, pos);
    }

    pub fn assignEntitiesToChunks(self: *ChunkedWorld, entities: []const Entity, positions: []const Position) !void {
        if (entities.len != positions.len) return error.MismatchedArrayLengths;

        for (entities, positions) |entity, position| {
            try self.setEntityPosition(entity, position);
        }
    }

    pub fn createEntity(self: *ChunkedWorld, id: u64, position: Position, renderable: Renderable) !Entity {
        const entity = Entity{ .id = id };

        // Add entity to the archetype-based world
        try self.world.createEntity(entity, position, renderable);

        // Assign to chunk based on position
        try self.assignToChunk(entity, position);

        return entity;
    }
};

// Camera System
pub fn updateCameraSystem(chunked_world: *ChunkedWorld, camera_entity: Entity) !void {
    const camera_opt = chunked_world.world.getComponent(Camera, camera_entity);
    if (camera_opt == null) return;

    var camera = camera_opt.?;

    // Handle camera panning
    const mouse_pos = rl.getMousePosition();

    if (rl.isMouseButtonPressed(.left)) {
        camera.is_dragging = true;
        camera.drag_start = mouse_pos;
    }

    if (rl.isMouseButtonDown(.left) and camera.is_dragging) {
        // Calculate the movement delta and move camera in opposite direction
        const delta_x = (mouse_pos.x - camera.drag_start.x) / camera.zoom;
        const delta_y = (mouse_pos.y - camera.drag_start.y) / camera.zoom;

        camera.target.x -= delta_x;
        camera.target.y -= delta_y;

        // Update drag start for next frame
        camera.drag_start = mouse_pos;
    }

    if (rl.isMouseButtonReleased(.left)) {
        camera.is_dragging = false;
    }

    // Handle zoom with mouse wheel
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        // Get world point before zoom
        const mouse_world_pos = rl.getScreenToWorld2D(mouse_pos, rl.Camera2D{
            .offset = camera.offset,
            .target = camera.target,
            .rotation = camera.rotation,
            .zoom = camera.zoom,
        });

        // Zoom increment
        camera.zoom += wheel * 0.1;
        if (camera.zoom < 0.1) camera.zoom = 0.1;

        // Get world point after zoom
        const new_mouse_world_pos = rl.getScreenToWorld2D(mouse_pos, rl.Camera2D{
            .offset = camera.offset,
            .target = camera.target,
            .rotation = camera.rotation,
            .zoom = camera.zoom,
        });

        // Adjust camera target to zoom on mouse position
        camera.target.x += mouse_world_pos.x - new_mouse_world_pos.x;
        camera.target.y += mouse_world_pos.y - new_mouse_world_pos.y;
    }

    try chunked_world.world.setComponent(Camera, camera_entity, camera);
}

// Rendering
pub fn renderChunkedWorld(world: ChunkedWorld) void {
    // Get main camera entity (this is a placeholder, would need to be actually tracked)
    var camera_entity_opt: ?Entity = null;
    if (world.world.archetypes.items.len > 0) {
        const arch = world.world.archetypes.items[0];
        for (arch.entities.items, 0..) |entity, i| {
            // Check if entity has a real camera (not the empty default one)
            const camera = arch.cameras.items[i];
            if (camera.zoom != 0) {
                camera_entity_opt = entity;
                break;
            }
        }
    }

    if (camera_entity_opt == null) return;

    const camera_entity = camera_entity_opt.?;
    const camera = world.world.getComponent(Camera, camera_entity) orelse return;

    // Begin 2D camera mode using the camera component
    const rl_camera = rl.Camera2D{
        .offset = camera.offset,
        .target = camera.target,
        .rotation = camera.rotation,
        .zoom = camera.zoom,
    };
    rl.beginMode2D(rl_camera);
    defer rl.endMode2D();

    // Draw grid lines to visualize chunks
    const chunk_size_f: f32 = @floatFromInt(world.chunk_size);

    // Draw vertical grid lines
    var x: f32 = 0;
    const screen_width_f: f32 = @floatFromInt(rl.getScreenWidth());
    while (x < screen_width_f) : (x += chunk_size_f) {
        rl.drawLine(@intFromFloat(x), 0, @intFromFloat(x), rl.getScreenHeight(), rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 });
    }

    // Draw horizontal grid lines
    var y: f32 = 0;
    const screen_height_f: f32 = @floatFromInt(rl.getScreenHeight());
    while (y < screen_height_f) : (y += chunk_size_f) {
        rl.drawLine(0, @intFromFloat(y), rl.getScreenWidth(), @intFromFloat(y), rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 });
    }

    // Draw each chunk with its entities
    var chunk_iter = world.chunks.iterator();
    while (chunk_iter.next()) |entry| {
        const chunk = entry.value_ptr.*;

        // Render chunk coordinate in the center of the chunk
        const chunk_center_x: f32 = (@as(f32, @floatFromInt(chunk.coord.x)) * chunk_size_f) + (chunk_size_f / 2);
        const chunk_center_y: f32 = (@as(f32, @floatFromInt(chunk.coord.y)) * chunk_size_f) + (chunk_size_f / 2);

        const coord_text = std.fmt.allocPrintZ(world.allocator, "({}, {})", .{ chunk.coord.x, chunk.coord.y }) catch continue;
        defer world.allocator.free(coord_text);

        rl.drawText(coord_text, @intFromFloat(chunk_center_x - 20), @intFromFloat(chunk_center_y), 12, rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 });

        // Draw entities in this chunk
        for (chunk.entities.items) |entity| {
            if (world.world.getComponent(Position, entity)) |position| {
                if (world.world.getComponent(Renderable, entity)) |renderable| {
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
}

// Game functions
pub const Game = struct {
    chunked_world: ChunkedWorld,
    camera_entity: Entity,
    entity_id_counter: u64,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !Game {
        var game = Game{
            .chunked_world = ChunkedWorld.init(allocator, chunk_size),
            .camera_entity = Entity{ .id = 1 },
            .entity_id_counter = 1,
        };

        // Create camera entity
        try game.chunked_world.world.createEntity(game.camera_entity, Position{ .x = 0, .y = 0 }, Renderable{
            .color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .width = 0,
            .height = 0,
            .shape = .Rectangle,
        });

        try game.chunked_world.world.archetypes.items[0].addCamera(game.camera_entity);

        // Increment ID counter
        game.entity_id_counter += 1;

        return game;
    }

    pub fn deinit(self: *Game) void {
        self.chunked_world.deinit();
    }

    pub fn createEntity(self: *Game, position: Position, renderable: Renderable) !Entity {
        const id = self.entity_id_counter;
        self.entity_id_counter += 1;
        return try self.chunked_world.createEntity(id, position, renderable);
    }

    pub fn update(self: *Game) !void {
        try updateCameraSystem(&self.chunked_world, self.camera_entity);
    }

    pub fn render(self: Game) void {
        renderChunkedWorld(self.chunked_world);
    }
};
