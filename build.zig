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

    exe.addIncludePath(.{ .cwd_relative = "/usr/include" });

    // Link system libraries (Linux examples). On macOS/Windows adjust accordingly.
    // exe.linkSystemLibrary("glfw");
    // exe.linkSystemLibrary("m");
    // exe.linkSystemLibrary("dl");
    // exe.linkSystemLibrary("X11");
    // exe.linkSystemLibrary("pthread");
    // exe.linkSystemLibrary("GL"); // On macOS replace with "OpenGL"

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
}
