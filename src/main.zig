const std = @import("std");

const button = @import("gui/widgets/button.zig").button;
const GLRenderer = @import("gui/renderers/opengl.zig").GLRenderer;
const GuiContext = @import("gui/context.zig").GuiContext;
const input = @import("gui/input.zig");
const c = @import("gui/c.zig");
const glfw = c.glfw;
const gl = c.glad;

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var renderer = GLRenderer.init();

    var gui = try GuiContext.init(allocator);
    defer gui.deinit();

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glClearColor(0.55, 0.55, 0.55, 1.0);
    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        gui.newFrame();
        input.updateInput(&gui, window);

        // Render buttons at different font sizes
        if (try button(&gui, .{ .x = 30, .y = 30, .w = 200, .h = 50 }, "hello world", 24, .{ 255, 200, 100, 255 })) {}
        if (try button(&gui, .{ .x = 250, .y = 30, .w = 250, .h = 70 }, "Large Text", 36, .{ 100, 200, 255, 255 })) {}
        if (try button(&gui, .{ .x = 30, .y = 120, .w = 150, .h = 30 }, "small text", 16, .{ 200, 100, 255, 255 })) {}

        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gui.render(&renderer, 1920, 1080);

        glfw.glfwSwapBuffers(window);
    }
}
