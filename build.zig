const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zgui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const glfw_dependency = b.dependency("glfw_zig", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.linkLibrary(glfw_dependency.artifact("glfw"));

    const glad_dependency = b.dependency("zig_glad", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.linkLibrary(glad_dependency.artifact("glad"));

    exe.root_module.addIncludePath(.{ .cwd_relative = "external/font" });
    exe.root_module.addCSourceFile(.{
        .file = b.path("external/font/stb_truetype.c"),
        .flags = &[_][]const u8{"-O3"},
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
}
