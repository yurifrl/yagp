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

const TypeId = std.meta.Hash([]const u8);
const ArchetypeId = u64;

const Archetype = struct {
    id: ArchetypeId,
    entities: std.ArrayList(Entity),
};

const World = struct {
    archetypes: std.ArrayList(Archetype),
    componentToArchetypes: std.StringHashMap(std.ArrayList(ArchetypeId)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return World{
            .archetypes = std.ArrayList(Archetype).init(allocator),
            .componentToArchetypes = std.StringHashMap(std.ArrayList(ArchetypeId)).init(allocator),
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
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "YAGP");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Main game loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
    }
}
