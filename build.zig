const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "blockbreaker",
        .root_module = exe_mod,
    });
    configGameDevDeps(b, exe, target, optimize);
    b.installArtifact(exe);

    // RUN
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TEST
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn configGameDevDeps(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    //---zglfw
    const zglfw = b.dependency("zglfw", .{
        .target = target,
    });
    artifact.root_module.addImport("zglfw", zglfw.module("root"));
    artifact.linkLibrary(zglfw.artifact("glfw"));

    //---zopengl
    const zopengl = b.dependency("zopengl", .{});
    artifact.root_module.addImport("zopengl", zopengl.module("root"));

    //---zstbi
    const zstbi = b.dependency("zstbi", .{});
    artifact.root_module.addImport("zstbi", zstbi.module("root"));

    //---zmath
    const zmath = b.dependency("zmath", .{});
    artifact.root_module.addImport("zmath", zmath.module("root"));

    //---zgui
    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_opengl3,
        .shared = false,
        .with_implot = true,
    });
    artifact.root_module.addImport("zgui", zgui.module("root"));
    artifact.linkLibrary(zgui.artifact("imgui"));

    const zaudio = b.dependency("zaudio", .{});
    artifact.root_module.addImport("zaudio", zaudio.module("root"));
    artifact.linkLibrary(zaudio.artifact("miniaudio"));

    const freetype = b.dependency(
        "freetype",
        .{ .target = target, .optimize = optimize },
    );
    artifact.linkLibrary(freetype.artifact("freetype"));

    //---system_sdk
    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
            artifact.addLibraryPath(system_sdk.path("macos12/usr/lib"));
            artifact.addSystemFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
        }
    }
}
