const std = @import("std");
const c = @import("gui/c.zig");
const glfw = c.glfw;
const gl = c.glad;

const input = @import("gui/input.zig");
const GuiContext = @import("gui/context.zig").GuiContext;

pub fn main() !void {
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return;
    }
    // BUG: glfwTerminate causing panic when window closes
    // defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1920, 1080, "zgui", null, null);
    if (window == null) {
        std.debug.print("Failed to create window", .{});
        return;
    }

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1); // VSYNC

    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        std.debug.print("Failed to load OpenGL\n", .{});
        return;
    }

    var gui = GuiContext.init();

    gl.glClearColor(0.55, 0.55, 0.55, 1.0);
    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        input.updateInput(&gui, window);

        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gui.render();

        glfw.glfwSwapBuffers(window);
    }
}
