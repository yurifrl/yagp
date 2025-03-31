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
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // Wasm
    // web exports are completely separate, reference: https://github.com/Not-Nik/raylib-zig/blob/devel/project_setup.sh
    if (target.result.os.tag == .emscripten) {
        const exe_lib = try rlz.emcc.compileForEmscripten(
            b,
            "hello",
            "src/main.zig",
            target,
            optimize,
        );

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = try rlz.emcc.linkWithEmscripten(
            b,
            &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact },
        );
        //this lets your program access files like "resources/my-image.png":
        // link_step.addArg("--embed-file");
        // link_step.addArg("resources/");

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run 'hello'");
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{ .name = "'$PROJECT_NAME'", .root_source_file = b.path("src/main.zig"), .optimize = optimize, .target = target });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run '$PROJECT_NAME'");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);

    //--------------------------------------------------------------------------------------------------
    // Native Server
    //--------------------------------------------------------------------------------------------------
    // Build options
    // Server
    const server = try addServer(b, target);
    const run_server = b.addRunArtifact(server);
    const run_server_step = b.step("server", "Run the server");
    run_server_step.dependOn(&run_server.step);

    //--------------------------------------------------------------------------------------------------
    // Native GUI
    //--------------------------------------------------------------------------------------------------
    const gui = try addGui(b, target, optimize, raylib, raygui, raylib_artifact);
    const run_gui = b.addRunArtifact(gui);
    const run_gui_step = b.step("gui", "Run the game");
    run_gui_step.dependOn(&run_gui.step);
}

fn addGui(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Module,
    raygui: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
) !*std.Build.Step.Compile {
    const gui = b.addExecutable(.{
        .name = "gui",
        .root_source_file = b.path("src/gui/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    gui.linkLibrary(raylib_artifact);
    gui.root_module.addImport("raylib", raylib);
    gui.root_module.addImport("raygui", raygui);
    b.installArtifact(gui);
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
    return server;
}
