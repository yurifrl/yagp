const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // Wasm
    // web exports are completely separate, reference: https://github.com/Not-Nik/raylib-zig/blob/devel/project_setup.sh
    if (target.result.os.tag == .emscripten) {
        try addWasm(b, target, optimize);
        return;
    }

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
    // GUI - Only set up dependencies if gui step is requested
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const gui = try addGui(b, target, optimize, raylib, raygui, raylib_artifact);
    const run_gui = b.addRunArtifact(gui);
    const run_gui_step = b.step("gui", "Run the game");
    run_gui_step.dependOn(&run_gui.step);
}

fn addGui(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *Build.Module,
    raygui: *Build.Module,
    raylib_artifact: *Build.Step.Compile,
) !*Build.Step.Compile {
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

fn addServer(b: *Build, target: Build.ResolvedTarget) !*Build.Step.Compile {
    const server = b.addExecutable(.{
        .name = "server",
        .root_source_file = b.path("src/server/server.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(server);
    return server;
}

fn addWasm(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const output_dir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
    const output_file = "index.html";

    const wasm = b.addStaticLibrary(.{
        .name = "hello_emcc",
        .root_source_file = b.path("src/main.zig"),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    const emcc_exe = switch (builtin.os.tag) {
        .windows => "emcc.bat",
        else => "emcc",
    };

    const mkdir_command = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", output_dir });
    const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe});
    emcc_command.addFileArg(wasm.getEmittedBin());
    emcc_command.step.dependOn(&wasm.step);
    emcc_command.step.dependOn(&mkdir_command.step);
    emcc_command.addArgs(&[_][]const u8{
        "-o",
        output_dir ++ output_file,
        "-O3",
        "-sASYNCIFY",
    });

    if (optimize == .Debug or optimize == .ReleaseSafe) {
        emcc_command.addArgs(&[_][]const u8{
            "-sUSE_OFFSET_CONVERTER",
        });
    }

    b.getInstallStep().dependOn(&emcc_command.step);
    b.installArtifact(wasm);
}
