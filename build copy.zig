const std = @import("std");
const rlz = @import("raylib_zig");
pub const emcc = @import("emcc.zig");

const number_of_pages = 2;

pub fn build(b: *std.Build) !void {
    // // ==========================================================================================
    // Raylib
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    // const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // ==========================================================================================
    // Build WASM game
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const game = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/wasm/game.zig"),
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

    const exe_lib = try rlz.emcc.compileForEmscripten(b, "game", "src/wasm/game.zig", target, optimize);
    exe_lib.linkLibrary(raylib_artifact);
    exe_lib.root_module.addImport("raylib", raylib);

    // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
    const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
    //this lets your program access files like "resources/my-image.png":
    link_step.addArg("--embed-file");
    link_step.addArg("resources/");

    b.getInstallStep().dependOn(&link_step.step);
    const run_step2 = try rlz.emcc.emscriptenRunStep(b);
    run_step2.step.dependOn(&link_step.step);
    const run_option = b.step("wasm", "Run wasm");
    run_option.dependOn(&run_step2.step);
}
