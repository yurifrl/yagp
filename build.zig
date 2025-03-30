const std = @import("std");

const number_of_pages = 2;

pub fn build(b: *std.Build) void {
    // ==========================================================================================
    // Native
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // ==========================================================================================
    // Build WASM game
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const game = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/game/game.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });

    // <https://github.com/ziglang/zig/issues/8633>
    game.global_base = 6560;
    game.entry = .disabled;
    game.rdynamic = true;
    game.import_memory = true;
    game.stack_size = std.wasm.page_size;

    game.initial_memory = std.wasm.page_size * number_of_pages;
    game.max_memory = std.wasm.page_size * number_of_pages;

    b.installArtifact(game);

    // ==========================================================================================
    // Build server
    const native_target = b.standardTargetOptions(.{});
    const server = b.addExecutable(.{
        .name = "server",
        .root_source_file = b.path("src/server/server.zig"),
        .target = native_target,
        .optimize = .ReleaseSafe,
    });

    b.installArtifact(server);
}
