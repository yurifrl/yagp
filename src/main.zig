const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

const ecs = @import("ecs.zig");
const chunking = @import("chunking.zig");
const camera_system = @import("camera.zig");
const utils = @import("utils.zig");

const is_wasm = builtin.target.os.tag == .emscripten;

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Initialize our chunked world with page allocator (WebAssembly compatible)
    const allocator = std.heap.page_allocator;

    var chunked_world = chunking.ChunkedWorld.init(allocator, 100); // 100x100 pixel chunks
    defer chunked_world.deinit();

    // Simple entity ID generator
    var entity_id_gen = utils.EntityIdGenerator.init();

    // Create a camera entity
    const camera_entity = ecs.Entity{ .id = entity_id_gen.next() };

    try chunked_world.world.createEntity(camera_entity, ecs.Position{ .x = 0, .y = 0 }, ecs.Renderable{
        .color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .width = 0,
        .height = 0,
        .shape = .Rectangle,
    });

    try chunked_world.world.archetypes.items[0].addCamera(camera_entity);

    // Create a red square entity
    _ = try chunked_world.createEntity(entity_id_gen.next(), ecs.Position{ .x = @floatFromInt(screenWidth / 2 - 25), .y = @floatFromInt(screenHeight / 2 - 25) }, ecs.Renderable{
        .color = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .width = 50,
        .height = 50,
        .shape = .Rectangle,
    });

    // Create some random test entities
    const positions = [_]ecs.Position{
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

    const colors = [_]rl.Color{
        .{ .r = 255, .g = 0, .b = 0, .a = 255 }, // Red
        .{ .r = 255, .g = 255, .b = 0, .a = 255 }, // Yellow
        .{ .r = 0, .g = 0, .b = 255, .a = 255 }, // Blue
        .{ .r = 0, .g = 255, .b = 0, .a = 255 }, // Green
    };

    for (0..20) |i| {
        const position = positions[i % positions.len];
        const color = colors[i % colors.len];

        const renderable = ecs.Renderable{
            .color = color,
            .width = 40,
            .height = 40,
            .shape = .Rectangle,
        };

        _ = try chunked_world.createEntity(entity_id_gen.next(), position, renderable);
    }

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update camera system
        try camera_system.updateCameraSystem(&chunked_world.world, camera_entity);

        // Get updated camera for rendering
        const camera = chunked_world.world.getCamera(camera_entity) orelse ecs.Camera{
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
        chunking.renderChunkedWorld(chunked_world, camera);

        // Display some debug info (drawn outside camera mode for fixed position)
        rl.drawFPS(10, 10);
    }
}
