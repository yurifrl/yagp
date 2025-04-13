const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs.zig");

pub fn updateCameraSystem(world: *ecs.World, camera_entity: ecs.Entity) !void {
    const camera_opt = world.getComponent(ecs.Camera, camera_entity);
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

    try world.setComponent(ecs.Camera, camera_entity, camera);
}
