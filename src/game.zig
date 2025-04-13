const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs.zig");

// Re-export core types for backwards compatibility
pub const Entity = ecs.Entity;
pub const Position = ecs.Position;
pub const Renderable = ecs.Renderable;
pub const Camera = ecs.Camera;

// Update camera system with raylib input
pub fn updateCameraSystem(chunked_world: *ecs.ChunkedWorld, camera_entity: ecs.Entity) !void {
    const camera_component = chunked_world.world.getComponent(ecs.Camera, camera_entity) orelse return;
    var camera = camera_component;

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

    try chunked_world.world.setComponent(ecs.Camera, camera_entity, camera);
}

// Rendering function
pub fn renderChunkedWorld(world: ecs.ChunkedWorld) void {
    // Get main camera entity (this is a placeholder, would need to be actually tracked)
    var camera_entity_opt: ?ecs.Entity = null;
    if (world.world.archetypes.items.len > 0) {
        const arch = world.world.archetypes.items[0];
        for (arch.entities.items, 0..) |entity, i| {
            // Check if entity has a camera
            if (arch.has_cameras.items[i]) {
                camera_entity_opt = entity;
                break;
            }
        }
    }

    if (camera_entity_opt == null) return;

    const camera_entity = camera_entity_opt.?;
    const camera_opt = world.world.getComponent(ecs.Camera, camera_entity);
    if (camera_opt == null) return;
    const camera = camera_opt.?;

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
            if (world.world.getComponent(ecs.Position, entity)) |position| {
                if (world.world.getComponent(ecs.Renderable, entity)) |renderable| {
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
    chunked_world: ecs.ChunkedWorld,
    camera_entity: ecs.Entity,

    pub fn init(allocator: std.mem.Allocator, chunk_size: i32) !Game {
        const chunked_world = try ecs.ChunkedWorld.init(allocator, chunk_size);

        return Game{
            .chunked_world = chunked_world,
            .camera_entity = chunked_world.camera_entity,
        };
    }

    pub fn deinit(self: *Game) void {
        self.chunked_world.deinit();
    }

    pub fn createEntity(self: *Game, position: ecs.Position, renderable: ecs.Renderable) !ecs.Entity {
        return try self.chunked_world.createEntity(position, renderable);
    }

    pub fn update(self: *Game) !void {
        try updateCameraSystem(&self.chunked_world, self.camera_entity);
    }

    pub fn render(self: Game) void {
        renderChunkedWorld(self.chunked_world);
    }
};
