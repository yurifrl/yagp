const std = @import("std");
// const builtin = @import("builtin");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    // GUI - Only set up dependencies if gui step is requested
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // Wasm
    // web exports are completely separate, reference: https://github.com/Not-Nik/raylib-zig/blob/devel/project_setup.sh
    // This needs to come first
    if (target.result.os.tag == .emscripten) {
        try addEmscripten(b, target, optimize, raylib, raylib_artifact);
        return;
    }
    //--------------------------------------------------------------------------------------------------
    // Native Server
    //--------------------------------------------------------------------------------------------------
    _ = try addServer(b, target);

    //--------------------------------------------------------------------------------------------------
    // Native GUI
    //--------------------------------------------------------------------------------------------------
    _ = try addGui(b, target, optimize, raylib, raylib_artifact);
}

fn addGui(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
) !*std.Build.Step.Compile {
    const gui = b.addExecutable(.{
        .name = "'$PROJECT_NAME'",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    b.installArtifact(gui);

    gui.linkLibrary(raylib_artifact);
    gui.root_module.addImport("raylib", raylib);

    const run_gui = b.addRunArtifact(gui);
    const run_gui_step = b.step("gui", "Run the game");
    run_gui_step.dependOn(&run_gui.step);

    return gui;
}

fn addServer(b: *std.Build, target: std.Build.ResolvedTarget) !*std.Build.Step.Compile {
    const server = b.addExecutable(.{
        .name = "server",
        .root_source_file = b.path("src/server/server.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(server);

    const run_server = b.addRunArtifact(server);
    const run_server_step = b.step("server", "Run the server");
    run_server_step.dependOn(&run_server.step);

    return server;
}

fn addEmscripten(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
) !void {
    const exe_lib = try rlz.emcc.compileForEmscripten(
        b,
        "hello",
        "src/main.zig",
        target,
        optimize,
    );

    exe_lib.linkLibrary(raylib_artifact);
    exe_lib.root_module.addImport("raylib", raylib);

    const link_step = try rlz.emcc.linkWithEmscripten(
        b,
        &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact },
    );

    b.getInstallStep().dependOn(&link_step.step);
    const run_step = try rlz.emcc.emscriptenRunStep(b);
    run_step.step.dependOn(&link_step.step);
    const run_option = b.step("web", "Run 'hello'");
    run_option.dependOn(&run_step.step);
}
