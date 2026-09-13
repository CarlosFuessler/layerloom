const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. HTML & Tailwind Studio Web Server (2mf-server)
    const server_exe = b.addExecutable(.{
        .name = "2mf-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(server_exe);

    const server_run_cmd = b.addRunArtifact(server_exe);
    server_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        server_run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the 2MF Studio Web Application");
    run_step.dependOn(&server_run_cmd.step);

    const server_step = b.step("server", "Run the 2MF Studio Web Application server");
    server_step.dependOn(&server_run_cmd.step);

    // 2. Raylib Native Desktop Application (2mf)
    const raylib_exe = b.addExecutable(.{
        .name = "2mf-raylib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    raylib_exe.root_module.addIncludePath(b.path("libs/stb"));
    const raylib_root = std.process.getEnvVarOwned(b.allocator, "RAYLIB_PATH") catch "/opt/homebrew/opt/raylib";
    const raylib_include = std.fmt.allocPrint(b.allocator, "{s}/include", .{raylib_root}) catch @panic("out of memory");
    const raylib_lib = std.fmt.allocPrint(b.allocator, "{s}/lib", .{raylib_root}) catch @panic("out of memory");
    raylib_exe.root_module.addIncludePath(.{ .cwd_relative = raylib_include });
    raylib_exe.root_module.addLibraryPath(.{ .cwd_relative = raylib_lib });
    if (target.result.os.tag == .macos) {
        raylib_exe.root_module.addRPath(.{ .cwd_relative = raylib_lib });
    }

    raylib_exe.root_module.linkSystemLibrary("raylib", .{ .preferred_link_mode = .static });

    if (target.result.os.tag == .macos) {
        raylib_exe.root_module.linkFramework("OpenGL", .{});
        raylib_exe.root_module.linkFramework("Cocoa", .{});
        raylib_exe.root_module.linkFramework("IOKit", .{});
        raylib_exe.root_module.linkFramework("CoreVideo", .{});
    } else if (target.result.os.tag == .windows) {
        raylib_exe.root_module.linkSystemLibrary("opengl32", .{});
        raylib_exe.root_module.linkSystemLibrary("gdi32", .{});
        raylib_exe.root_module.linkSystemLibrary("winmm", .{});
    }

    raylib_exe.root_module.addCSourceFiles(.{
        .files = &.{"libs/stb/stb_image_impl.c"},
        .flags = &.{"-std=c99"},
    });

    b.installArtifact(raylib_exe);

    const raylib_run_cmd = b.addRunArtifact(raylib_exe);
    const raylib_step = b.step("raylib", "Run the Raylib native application");
    raylib_step.dependOn(&raylib_run_cmd.step);

    // 3. Unit Tests
    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe_unit_tests.root_module.addIncludePath(b.path("libs/stb"));
    exe_unit_tests.root_module.addCSourceFiles(.{
        .files = &.{"libs/stb/stb_image_impl.c"},
        .flags = &.{"-std=c99"},
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // 4. Sample Exporter CLI
    const export_exe = b.addExecutable(.{
        .name = "export_sample",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_export.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    export_exe.root_module.addIncludePath(b.path("libs/stb"));
    export_exe.root_module.addCSourceFiles(.{
        .files = &.{"libs/stb/stb_image_impl.c"},
        .flags = &.{"-std=c99"},
    });
    b.installArtifact(export_exe);

    const export_run_cmd = b.addRunArtifact(export_exe);
    const export_step = b.step("export_sample", "Run sample 3MF & STL export generation");
    export_step.dependOn(&export_run_cmd.step);
}
