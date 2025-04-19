const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
//
const game = @import("game.zig");
const debugger = @import("debugger.zig");
const ui = @import("ui.zig");
const ecs = @import("ecs.zig");

// Constants
const is_wasm = builtin.target.os.tag == .emscripten;
const screenWidth = 800;
const screenHeight = 450;

pub fn main() anyerror!void {
    if (is_wasm) {
        // Hello wasm
    }

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Initialize our game with page allocator (WebAssembly compatible)
    // Wasm not being used right now
    const allocator = if (is_wasm) std.heap.wasm_allocator else std.heap.page_allocator;

    // Initialize debugger
    debugger.init(allocator);
    defer debugger.deinit();

    // Initialize game
    var g = try game.Game.init(allocator, 100); // 100x100 pixel chunks
    defer g.deinit();

    // Initialize UI
    var ui_system = ui.UI.init(allocator);
    defer ui_system.deinit();

    // Add a debug message
    debugger.log("Game initialized");

    // Add a frame to the UI
    _ = ui_system.addFrame()
        .setMargin(1.0)
        .setThickness(0.5)
        .setColor(rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });

    // Initialize a dynamic bar
    ui_system.initDynamicBar(15.0, 10.0, 5.0); // 15mm height, 10mm buttons, 2mm spacing

    // Define buttons
    const buttons = [_]ui.UI.BarItem{
        .{
            .id = "residential",
            .label = "Residential",
            .color = rl.Color{ .r = 100, .g = 100, .b = 200, .a = 255 },
        },
        .{
            .id = "commercial",
            .label = "Commercial",
            .color = rl.Color{ .r = 200, .g = 100, .b = 100, .a = 255 },
        },
        .{
            .id = "industrial",
            .label = "Industrial",
            .color = rl.Color{ .r = 100, .g = 200, .b = 100, .a = 255 },
        },
    };

    // Load buttons
    ui_system.loadButtons(&buttons);

    // Initialize inspector in debugger
    // try debugger.initInspector(10, 30, 250, 400);

    // Create a red square entity
    _ = try g.createEntity(game.Position{ .x = @floatFromInt(screenWidth / 2 - 25), .y = @floatFromInt(screenHeight / 2 - 25) }, game.Renderable{
        .color = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .width = 50,
        .height = 50,
        .shape = .Rectangle,
    });

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update inspector with current entity data
        // debugger.updateInspector(&g) catch {};

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        // Render the game world
        try g.renderWorld();

        // Render UI on top
        ui_system.render();

        // // Check for button clicks
        if (ui_system.getClickedButton()) |button_id| {
            debugger.logFmt("Button clicked: {s}", .{button_id});
        }

        // Render debug messages (also renders inspector)
        debugger.render();

        // Display some debug info
        rl.drawFPS(10, 10);
    }
}
