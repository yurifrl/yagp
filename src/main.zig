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
};

const World = struct {
    archetypes: std.ArrayList(Archetype),
    componentToArchetypes: std.StringHashMap(std.ArrayList(ArchetypeId)),
    positionComponents: std.AutoHashMap(u64, Position),
    renderableComponents: std.AutoHashMap(u64, Renderable),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return World{
            .archetypes = std.ArrayList(Archetype).init(allocator),
            .componentToArchetypes = std.StringHashMap(std.ArrayList(ArchetypeId)).init(allocator),
            .positionComponents = std.AutoHashMap(u64, Position).init(allocator),
            .renderableComponents = std.AutoHashMap(u64, Renderable).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.archetypes.deinit();
        var iter = self.componentToArchetypes.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.componentToArchetypes.deinit();
        self.positionComponents.deinit();
        self.renderableComponents.deinit();
    }

    pub fn setPosition(self: *World, entity: Entity, position: Position) !void {
        try self.positionComponents.put(entity.id, position);
    }

    pub fn getPosition(self: World, entity: Entity) ?Position {
        return self.positionComponents.get(entity.id);
    }

    pub fn setRenderable(self: *World, entity: Entity, renderable: Renderable) !void {
        try self.renderableComponents.put(entity.id, renderable);
    }

    pub fn getRenderable(self: World, entity: Entity) ?Renderable {
        return self.renderableComponents.get(entity.id);
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
        try self.world.setPosition(entity, pos);
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
        try self.setEntityPosition(entity, position);
        try self.world.setRenderable(entity, renderable);
        return entity;
    }
};

pub fn renderChunkedWorld(world: ChunkedWorld) void {
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

    // Setup random number generator
    var component_generator = ComponentGenerator.init(allocator);

    // Create a red square entity
    _ = try chunked_world.createEntity(component_generator.entity_counter, Position{ .x = @floatFromInt(screenWidth / 2 - 25), .y = @floatFromInt(screenHeight / 2 - 25) }, Renderable{
        .color = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .width = 50,
        .height = 50,
        .shape = .Rectangle,
    });
    component_generator.entity_counter += 1;

    // Create some random test entities
    for (0..20) |_| {
        _ = try component_generator.createEntity(&chunked_world);
    }

    // Main game loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        // Render the chunked world
        renderChunkedWorld(chunked_world);

        // Display some debug info
        rl.drawFPS(10, 10);
    }
}

const ComponentGenerator = struct {
    index: usize,
    entity_counter: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ComponentGenerator {
        return ComponentGenerator{
            .index = 0,
            .entity_counter = 1,
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

    pub fn createEntity(self: *ComponentGenerator, world: *ChunkedWorld) !Entity {
        const position = self.nextPosition();
        const renderable = self.nextRenderable();
        const entity = try world.createEntity(self.entity_counter, position, renderable);
        self.entity_counter += 1;
        return entity;
    }
};
