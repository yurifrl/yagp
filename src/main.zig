const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

const game = @import("game.zig");
const debugger = @import("debugger.zig");

const is_wasm = builtin.target.os.tag == .emscripten;

pub fn main() anyerror!void {
    if (is_wasm) {
        // Hello wasm
    }

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Initialize our game with page allocator (WebAssembly compatible)
    const allocator = std.heap.page_allocator;

    // Initialize debugger
    debugger.init(allocator);
    defer debugger.deinit();

    var g = try game.Game.init(allocator, 100); // 100x100 pixel chunks
    defer g.deinit();

    // Create a red square entity
    _ = try g.createEntity(game.Position{ .x = @floatFromInt(screenWidth / 2 - 25), .y = @floatFromInt(screenHeight / 2 - 25) }, game.Renderable{
        .color = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .width = 50,
        .height = 50,
        .shape = .Rectangle,
    });

    // Add a debug message
    debugger.log("Game initialized");

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update game
        try g.update();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        // Render the game world
        g.render();

        // Render debug messages
        debugger.render();

        // Display some debug info
        rl.drawFPS(10, 10);
    }
}
