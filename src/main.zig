// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

// Disable debug features on WebAssembly targets
const is_wasm = builtin.target.isWasm();

// Completely eliminate debug code when targeting WebAssembly
fn debugPrint(comptime _: []const u8, _: anytype) void {
    return;
}

const GameObject = struct {
    position: rl.Vector2, // Screen position
    objectType: ObjectType,
    color: rl.Color,
    size: rl.Vector2, // Size of the rectangle
};

const ObjectType = enum {
    building1,
    building2,
    building3,
    // Add more building types as needed
};

fn getBuildingProperties(objectType: ObjectType) struct { size: rl.Vector2, color: rl.Color } {
    return switch (objectType) {
        .building1 => .{
            .size = rl.Vector2.init(50, 45),
            .color = rl.Color.red,
        },
        .building2 => .{
            .size = rl.Vector2.init(50, 45),
            .color = rl.Color.blue,
        },
        .building3 => .{
            .size = rl.Vector2.init(12, 150),
            .color = rl.Color.purple,
        },
    };
}

const GameState = struct {
    objects: std.ArrayList(GameObject),
    cursorPosition: rl.Vector2,
    isRunning: bool,
    selectedObject: GameObject,
    const max_objects = 100; // Limit objects to prevent memory issues

    pub fn init(allocator: std.mem.Allocator) !GameState {
        const defaultProps = getBuildingProperties(.building1);

        return .{
            .objects = std.ArrayList(GameObject).init(allocator),
            .cursorPosition = rl.Vector2.init(0, 0),
            .isRunning = true,
            .selectedObject = .{
                .position = rl.Vector2.init(0, 0),
                .objectType = .building1,
                .color = defaultProps.color,
                .size = defaultProps.size,
            },
        };
    }

    pub fn deinit(self: *GameState) void {
        self.objects.deinit();
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow(); // Close window and OpenGL context

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var state = try GameState.init(allocator);
    defer state.deinit();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose() and state.isRunning) {
        // Update
        //----------------------------------------------------------------------------------
        state.cursorPosition = rl.getMousePosition();
        // Center the object below the cursor based on its size
        state.selectedObject.position.x = state.cursorPosition.x - state.selectedObject.size.x / 2;
        state.selectedObject.position.y = state.cursorPosition.y - state.selectedObject.size.y / 2;

        if (rl.isMouseButtonPressed(.left) and state.objects.items.len < GameState.max_objects) {
            try state.objects.append(.{
                .position = state.selectedObject.position,
                .objectType = state.selectedObject.objectType,
                .color = state.selectedObject.color,
                .size = state.selectedObject.size,
            });
            debugPrint("left\n", .{});
        } else if (rl.isMouseButtonPressed(.middle)) {
            debugPrint("middle\n", .{});
        } else if (rl.isMouseButtonPressed(.right)) {
            debugPrint("right\n", .{});
        }

        if (rl.isKeyPressed(.one)) {
            const props = getBuildingProperties(.building1);
            state.selectedObject.objectType = .building1;
            state.selectedObject.size = props.size;
            state.selectedObject.color = props.color;
            debugPrint("one\n", .{});
        } else if (rl.isKeyPressed(.two)) {
            const props = getBuildingProperties(.building2);
            state.selectedObject.objectType = .building2;
            state.selectedObject.size = props.size;
            state.selectedObject.color = props.color;
            debugPrint("two\n", .{});
        } else if (rl.isKeyPressed(.three)) {
            const props = getBuildingProperties(.building3);
            state.selectedObject.objectType = .building3;
            state.selectedObject.size = props.size;
            state.selectedObject.color = props.color;
            debugPrint("three\n", .{});
        }
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.green);

        // Draw the current building below the cursor
        rl.drawRectangleV(state.selectedObject.position, state.selectedObject.size, state.selectedObject.color);

        // Draw all placed buildings
        for (state.objects.items) |object| {
            rl.drawRectangleV(object.position, object.size, object.color);
        }

        rl.drawText("Press 1, 2 or 3 to select building", 10, 10, 20, .dark_gray);
        //----------------------------------------------------------------------------------
    }
}
