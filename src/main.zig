// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");
const GameObject = struct {
    position: rl.Vector2, // Screen position
    objectType: ObjectType,
    color: rl.Color,
    id: u32,
    slot: u8, // Position from 0 to 9
    sourceRec: rl.Rectangle, // Source rectangle in the texture
};

const ObjectType = enum {
    building1,
    building2,
    building3,
    // Add more building types as needed
};

const BuildingInfo = struct {
    sourceRec: rl.Rectangle,
};

const Assets = struct {
    texture: rl.Texture,
    buildings: std.EnumArray(ObjectType, BuildingInfo),

    pub fn init(texturePath: [:0]const u8) !Assets {
        var assets = Assets{
            .texture = try rl.Texture.init(texturePath),
            .buildings = std.EnumArray(ObjectType, BuildingInfo).initUndefined(),
        };

        // Define building information
        assets.buildings.set(.building1, .{
            .sourceRec = rl.Rectangle.init(120, 300, 50, 45),
        });
        assets.buildings.set(.building2, .{
            .sourceRec = rl.Rectangle.init(120, 170, 50, 45),
        });
        assets.buildings.set(.building3, .{
            .sourceRec = rl.Rectangle.init(12, 0, 12, 150),
        });

        return assets;
    }

    pub fn deinit(self: *Assets) void {
        rl.unloadTexture(self.texture);
    }

    pub fn getBuildingInfo(self: *const Assets, objectType: ObjectType) BuildingInfo {
        return self.buildings.get(objectType);
    }
};

const GameState = struct {
    objects: std.ArrayList(GameObject),
    cursorPosition: rl.Vector2,
    isRunning: bool,
    assets: Assets,
    selectedObject: GameObject,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var assets = try Assets.init("resources/City_Transparent/City_Transparent.png");
        const defaultBuildingInfo = assets.getBuildingInfo(.building1);

        return .{
            .objects = std.ArrayList(GameObject).init(allocator),
            .cursorPosition = rl.Vector2.init(0, 0),
            .isRunning = true,
            .assets = assets,
            .selectedObject = .{
                .position = rl.Vector2.init(0, 0),
                .objectType = .building1,
                .color = .white,
                .id = 0,
                .slot = 0,
                .sourceRec = defaultBuildingInfo.sourceRec,
            },
        };
    }

    pub fn deinit(self: *GameState) void {
        self.objects.deinit();
        self.assets.deinit();
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow(); // Close window and OpenGL context

    var state = try GameState.init(std.heap.page_allocator);
    defer state.deinit();

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose() and state.isRunning) {
        // Update
        //----------------------------------------------------------------------------------
        state.cursorPosition = rl.getMousePosition();
        state.selectedObject.position.x = state.cursorPosition.x;
        state.selectedObject.position.y = state.cursorPosition.y;

        if (rl.isMouseButtonPressed(.left)) {
            try state.objects.append(.{
                .position = state.cursorPosition,
                .objectType = state.selectedObject.objectType,
                .color = .white,
                .id = 0,
                .slot = 0,
                .sourceRec = state.selectedObject.sourceRec,
            });
            std.debug.print("left\n", .{});
        } else if (rl.isMouseButtonPressed(.middle)) {
            std.debug.print("middle\n", .{});
        } else if (rl.isMouseButtonPressed(.right)) {
            std.debug.print("right\n", .{});
        }

        if (rl.isKeyPressed(.one)) {
            state.selectedObject.objectType = .building1;
            state.selectedObject.sourceRec = state.assets.getBuildingInfo(.building1).sourceRec;
            std.debug.print("one\n", .{});
        } else if (rl.isKeyPressed(.two)) {
            state.selectedObject.objectType = .building2;
            state.selectedObject.sourceRec = state.assets.getBuildingInfo(.building2).sourceRec;
            std.debug.print("two\n", .{});
        } else if (rl.isKeyPressed(.three)) {
            state.selectedObject.objectType = .building3;
            state.selectedObject.sourceRec = state.assets.getBuildingInfo(.building3).sourceRec;
            std.debug.print("three\n", .{});
        }
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.green);

        // Draw the current building below the cursor
        state.assets.texture.drawRec(state.selectedObject.sourceRec, state.selectedObject.position, state.selectedObject.color);

        // Draw all placed buildings
        for (state.objects.items) |object| {
            state.assets.texture.drawRec(object.sourceRec, object.position, object.color);
        }

        rl.drawText("Press 1, 2 or 3 to select building", 10, 10, 20, .dark_gray);
        //----------------------------------------------------------------------------------
    }
}
