const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const is_wasm = builtin.target.os.tag == .emscripten;

const Entity = struct {
    id: u64,
};

const Position = struct {
    x: f32,
    y: f32,
};

const Renderable = struct {
    color: rl.Color,
    width: f32,
    height: f32,
    shape: enum { Rectangle, Circle, Texture },
    texture_id: ?u32 = null,
};

const Camera = struct {
    offset: rl.Vector2,
    target: rl.Vector2,
    rotation: f32,
    zoom: f32,
    is_dragging: bool,
    drag_start: rl.Vector2,
};

const ChunkCoord = struct {
    x: i32,
    y: i32,
};

const Chunk = struct {
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

const TypeId = std.meta.Hash([]const u8);
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

        // Initialize with empty camera component
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

    pub fn removeEntity(self: *Archetype, entity_id: u64) bool {
        if (self.getEntityIndex(entity_id)) |index| {
            _ = self.entities.orderedRemove(index);
            _ = self.positions.orderedRemove(index);
            _ = self.renderables.orderedRemove(index);
            return true;
        }
        return false;
    }
};

const World = struct {
    archetypes: std.ArrayList(Archetype),
    entityToArchetype: std.AutoHashMap(u64, usize), // Maps entity ID to archetype index
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
        // For now, we only have one archetype with both Position and Renderable
        if (self.archetypes.items.len == 0) {
            const archetype = Archetype.init(self.allocator, 1);
            try self.archetypes.append(archetype);
        }

        const archetype_index = 0;
        try self.archetypes.items[archetype_index].addEntity(entity, position, renderable);
        try self.entityToArchetype.put(entity.id, archetype_index);
    }

    pub fn setPosition(self: *World, entity: Entity, position: Position) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                archetype.positions.items[entity_index] = position;
            }
        }
    }

    pub fn getPosition(self: World, entity: Entity) ?Position {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                return archetype.positions.items[entity_index];
            }
        }
        return null;
    }

    pub fn setRenderable(self: *World, entity: Entity, renderable: Renderable) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                archetype.renderables.items[entity_index] = renderable;
            }
        }
    }

    pub fn getRenderable(self: World, entity: Entity) ?Renderable {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                return archetype.renderables.items[entity_index];
            }
        }
        return null;
    }

    pub fn removeEntity(self: *World, entity: Entity) bool {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            const removed = archetype.removeEntity(entity.id);
            if (removed) {
                _ = self.entityToArchetype.remove(entity.id);
                return true;
            }
        }
        return false;
    }

    pub fn setCamera(self: *World, entity: Entity, camera: Camera) !void {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = &self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                archetype.cameras.items[entity_index] = camera;
            }
        }
    }

    pub fn getCamera(self: World, entity: Entity) ?Camera {
        if (self.entityToArchetype.get(entity.id)) |archetype_index| {
            const archetype = self.archetypes.items[archetype_index];
            if (archetype.getEntityIndex(entity.id)) |entity_index| {
                return archetype.cameras.items[entity_index];
            }
        }
        return null;
    }
};

const ChunkedWorld = struct {
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
        if (self.world.getPosition(entity)) |old_pos| {
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
        try self.world.setPosition(entity, pos);

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

pub fn renderChunkedWorld(world: ChunkedWorld, camera: Camera) void {
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
            if (world.world.getPosition(entity)) |position| {
                if (world.world.getRenderable(entity)) |renderable| {
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

// Camera system to handle camera input and updates
pub fn updateCameraSystem(world: *World, camera_entity: Entity) !void {
    const camera_opt = world.getCamera(camera_entity);
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

    try world.setCamera(camera_entity, camera);
}

const EntityIdGenerator = struct {
    next_id: u64,

    pub fn init() EntityIdGenerator {
        return EntityIdGenerator{
            .next_id = 1,
        };
    }

    pub fn next(self: *EntityIdGenerator) u64 {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Initialize our chunked world with page allocator (WebAssembly compatible)
    const allocator = std.heap.page_allocator;

    var chunked_world = ChunkedWorld.init(allocator, 100); // 100x100 pixel chunks
    defer chunked_world.deinit();

    // Simple entity ID generator
    var entity_id_gen = EntityIdGenerator.init();

    // Create a camera entity
    const camera_entity = Entity{ .id = entity_id_gen.next() };

    try chunked_world.world.createEntity(camera_entity, Position{ .x = 0, .y = 0 }, Renderable{
        .color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .width = 0,
        .height = 0,
        .shape = .Rectangle,
    });

    try chunked_world.world.archetypes.items[0].addCamera(camera_entity);

    // Create a red square entity
    _ = try chunked_world.createEntity(entity_id_gen.next(), Position{ .x = @floatFromInt(screenWidth / 2 - 25), .y = @floatFromInt(screenHeight / 2 - 25) }, Renderable{
        .color = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .width = 50,
        .height = 50,
        .shape = .Rectangle,
    });

    // Create some random test entities
    var test_gen = ComponentGenerator.init(allocator);
    for (0..20) |_| {
        const position = test_gen.nextPosition();
        const renderable = test_gen.nextRenderable();
        _ = try chunked_world.createEntity(entity_id_gen.next(), position, renderable);
    }

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update camera system
        try updateCameraSystem(&chunked_world.world, camera_entity);

        // Get updated camera for rendering
        const camera = chunked_world.world.getCamera(camera_entity) orelse Camera{
            .offset = rl.Vector2{ .x = 0, .y = 0 },
            .target = rl.Vector2{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = 1.0,
            .is_dragging = false,
            .drag_start = rl.Vector2{ .x = 0, .y = 0 },
        };

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        // Render the chunked world with camera
        renderChunkedWorld(chunked_world, camera);

        // Display some debug info (drawn outside camera mode for fixed position)
        rl.drawFPS(10, 10);
    }
}

const ComponentGenerator = struct {
    index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ComponentGenerator {
        return ComponentGenerator{
            .index = 0,
            .allocator = allocator,
        };
    }

    pub fn nextPosition(self: *ComponentGenerator) Position {
        const positions = [_]Position{
            .{ .x = 100, .y = 100 },
            .{ .x = 200, .y = 150 },
            .{ .x = 300, .y = 200 },
            .{ .x = 400, .y = 250 },
            .{ .x = 500, .y = 300 },
            .{ .x = 150, .y = 350 },
            .{ .x = 250, .y = 400 },
            .{ .x = 350, .y = 100 },
            .{ .x = 450, .y = 150 },
            .{ .x = 550, .y = 200 },
        };

        const result = positions[self.index % positions.len];
        self.index += 1;
        return result;
    }

    pub fn nextRenderable(self: *ComponentGenerator) Renderable {
        const colors = [_]rl.Color{
            .{ .r = 255, .g = 0, .b = 0, .a = 255 }, // Red
            .{ .r = 255, .g = 255, .b = 0, .a = 255 }, // Yellow
            .{ .r = 0, .g = 0, .b = 255, .a = 255 }, // Blue
            .{ .r = 0, .g = 255, .b = 0, .a = 255 }, // Green
        };

        return Renderable{
            .color = colors[self.index % colors.len],
            .width = 40,
            .height = 40,
            .shape = .Rectangle,
        };
    }
};
