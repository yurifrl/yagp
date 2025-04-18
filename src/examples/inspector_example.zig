const std = @import("std");
const rl = @import("raylib");
const ui = @import("../ui.zig");

pub fn main() !void {
    // Initialize raylib
    const screenWidth = 800;
    const screenHeight = 600;
    rl.initWindow(screenWidth, screenHeight, "World Inspector Example");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Create UI system
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ui_system = ui.UI.init(allocator);
    defer ui_system.deinit();

    // Create the inspector
    const inspector = try ui_system.addInspector("World Inspector", 20, 20, 300, 500);

    // Create the tree structure

    // Entities node
    const entities_node = try inspector.addNode("Entities");

    // Add mesh entities
    _ = try entities_node.addChild("Pbr Mesh (0)");
    _ = try entities_node.addChild("Pbr Mesh (1)");

    // Add point light with components
    const point_light = try entities_node.addChild("PointLight (2)");
    point_light.addChild("ComputedVisibility") catch {};
    point_light.addChild("CubemapFrusta") catch {};
    point_light.addChild("CubemapVisibleEntities") catch {};
    point_light.addChild("GlobalTransform") catch {};
    point_light.addChild("PointLight") catch {};
    point_light.addChild("Transform") catch {};
    point_light.addChild("Visibility") catch {};

    // Add camera entity
    _ = try entities_node.addChild("Camera3d (3)");

    // Add assets section
    const assets_node = try inspector.addNode("Assets");
    assets_node.addChild("AnimationClip") catch {};
    assets_node.addChild("ColorMaterial") catch {};
    assets_node.addChild("Image") catch {};
    assets_node.addChild("StandardMaterial") catch {};
    assets_node.addChild("TextureAtlas") catch {};

    // Add resources node
    _ = try inspector.addNode("Resources");

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.BLACK);

        // Draw UI
        ui_system.render();

        // Draw instructions
        rl.drawText("Inspector Example", 340, 20, 20, rl.WHITE);
        rl.drawText("Simple ASCII Tree View", 340, 50, 18, rl.LIGHTGRAY);
    }
}
