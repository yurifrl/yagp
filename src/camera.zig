const std = @import("std");
const rl = @import("raylib");

pub const Camera = struct {
    offset: rl.Vector2,
    target: rl.Vector2,
    rotation: f32,
    zoom: f32,
    is_dragging: bool,
    drag_start: rl.Vector2,

    pub fn init(start_position: rl.Vector2) Camera {
        return Camera{
            .offset = rl.Vector2{ .x = 0, .y = 0 },
            .target = start_position,
            .rotation = 0,
            .zoom = 1.0,
            .is_dragging = false,
            .drag_start = rl.Vector2{ .x = 0, .y = 0 },
        };
    }

    pub fn toRaylib(self: Camera) rl.Camera2D {
        return .{
            .offset = self.offset,
            .target = self.target,
            .rotation = self.rotation,
            .zoom = self.zoom,
        };
    }
};

// Update camera system with raylib input
pub fn updateSystem(camera: *Camera) void {
    // Handle camera panning
    const mouse_pos = rl.getMousePosition();

    if (rl.isMouseButtonPressed(.left)) {
        camera.is_dragging = true;
        camera.drag_start = mouse_pos;
        // debugger.logFmt("Camera drag started at ({d:.1}, {d:.1})", .{ mouse_pos.x, mouse_pos.y });
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
        // debugger.logFmt("Camera position: ({d:.1}, {d:.1})", .{ camera.target.x, camera.target.y });
    }

    // Handle zoom with mouse wheel
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        // Get world point before zoom
        const mouse_world_pos = rl.getScreenToWorld2D(mouse_pos, camera.toRaylib());

        // Zoom increment
        camera.zoom += wheel * 0.1;
        if (camera.zoom < 0.1) camera.zoom = 0.1;

        // Get world point after zoom
        const new_mouse_world_pos = rl.getScreenToWorld2D(mouse_pos, camera.toRaylib());

        // Adjust camera target to zoom on mouse position
        camera.target.x += mouse_world_pos.x - new_mouse_world_pos.x;
        camera.target.y += mouse_world_pos.y - new_mouse_world_pos.y;
    }
}

pub fn getScreenBoundsWorld(camera: Camera, screen_width: i32, screen_height: i32) struct { top_left: rl.Vector2, bottom_right: rl.Vector2 } {
    const top_left = rl.getScreenToWorld2D(.{ .x = 0, .y = 0 }, camera.toRaylib());
    const bottom_right = rl.getScreenToWorld2D(.{ .x = @floatFromInt(screen_width), .y = @floatFromInt(screen_height) }, camera.toRaylib());

    return .{
        .top_left = top_left,
        .bottom_right = bottom_right,
    };
}
