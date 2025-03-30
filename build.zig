// const std = @import("std");
// const rlz = @import("raylib_zig");
// pub const emcc = @import("emcc.zig");

// const number_of_pages = 2;

// pub fn build(b: *std.Build) !void {
//     // // ==========================================================================================
//     // Raylib
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const raylib_dep = b.dependency("raylib_zig", .{
//         .target = target,
//         .optimize = optimize,
//     });

//     const raylib = raylib_dep.module("raylib"); // main raylib module
//     // const raygui = raylib_dep.module("raygui"); // raygui module
//     const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

//     // // ==========================================================================================
//     // // Native
//     // const gui = b.addExecutable(.{
//     //     .name = "gui",
//     //     .root_source_file = b.path("src/gui/main.zig"),
//     //     .optimize = optimize,
//     //     .target = target,
//     // });

//     // gui.linkLibrary(raylib_artifact);
//     // gui.root_module.addImport("raylib", raylib);
//     // gui.root_module.addImport("raygui", raygui);

//     // const run_exe = b.addRunArtifact(gui);

//     // const run_step = b.step("run", "Run the game");
//     // run_step.dependOn(&run_exe.step);

//     // b.installArtifact(gui);
//     // // ==========================================================================================
//     // // Build WASM game
//     // const wasm_target = b.resolveTargetQuery(.{
//     //     .cpu_arch = .wasm32,
//     //     .os_tag = .freestanding,
//     // });

//     // const game = b.addExecutable(.{
//     //     .name = "game",
//     //     .root_source_file = b.path("src/wasm/game.zig"),
//     //     .target = wasm_target,
//     //     .optimize = .ReleaseSmall,
//     // });

//     // // <https://github.com/ziglang/zig/issues/8633>
//     // game.global_base = 6560;
//     // game.entry = .disabled;
//     // game.rdynamic = true;
//     // game.import_memory = true;
//     // game.stack_size = std.wasm.page_size;

//     // game.initial_memory = std.wasm.page_size * number_of_pages;
//     // game.max_memory = std.wasm.page_size * number_of_pages;

//     // b.installArtifact(game);

//     // // ==========================================================================================
//     // // Build server
//     // const server = b.addExecutable(.{
//     //     .name = "server",
//     //     .root_source_file = b.path("src/server/server.zig"),
//     //     .target = target,
//     //     .optimize = .ReleaseSafe,
//     // });

//     // const run_server = b.addRunArtifact(server);
//     // const run_server_step = b.step("server", "Run the server");
//     // run_server_step.dependOn(&run_server.step);

//     // b.installArtifact(server);

//     // ==========================================================================================

//     const exe_lib = try rlz.emcc.compileForEmscripten(b, "game", "src/wasm/game.zig", target, optimize);
//     exe_lib.linkLibrary(raylib_artifact);
//     exe_lib.root_module.addImport("raylib", raylib);

//     // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
//     const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
//     //this lets your program access files like "resources/my-image.png":
//     link_step.addArg("--embed-file");
//     link_step.addArg("resources/");

//     b.getInstallStep().dependOn(&link_step.step);
//     const run_step2 = try rlz.emcc.emscriptenRunStep(b);
//     run_step2.step.dependOn(&link_step.step);
//     const run_option = b.step("wasm", "Run wasm");
//     run_option.dependOn(&run_step2.step);
// }
// }

const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;

const emccOutputDir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
const emccOutputFile = "index.html";

pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    if (target.result.os.tag == .emscripten) {
        const lib = b.addStaticLibrary(.{
            .name = "hello_emcc",
            .root_source_file = b.path("main.zig"),

            .link_libc = true,
            .target = target,
            .optimize = optimize,
        });

        const emcc_exe = switch (builtin.os.tag) {
            .windows => "emcc.bat",
            else => "emcc",
        };

        const mkdir_command = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", emccOutputDir });
        const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe});
        emcc_command.addFileArg(lib.getEmittedBin());
        emcc_command.step.dependOn(&lib.step);
        emcc_command.step.dependOn(&mkdir_command.step);
        emcc_command.addArgs(&[_][]const u8{
            "-o",
            emccOutputDir ++ emccOutputFile,
            "-O3",
            "-sASYNCIFY",
        });

        // emcc flag necessary for debug builds
        if (optimize == .Debug or optimize == .ReleaseSafe) {
            emcc_command.addArgs(&[_][]const u8{
                "-sUSE_OFFSET_CONVERTER",
            });
        }
        b.getInstallStep().dependOn(&emcc_command.step);
    } else {
        const exe = b.addExecutable(.{
            .name = "hello_emcc",
            .root_source_file = b.path("main.zig"),

            .target = target,
            .optimize = optimize,
        });

        b.installArtifact(exe);
    }

    // ==========================================================================================
    // Build server
    const server = b.addExecutable(.{
        .name = "server",
        .root_source_file = b.path("src/server/server.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });

    const run_server = b.addRunArtifact(server);
    const run_server_step = b.step("server", "Run the server");
    run_server_step.dependOn(&run_server.step);

    b.installArtifact(server);
}
