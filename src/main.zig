const std = @import("std");
const build_options = @import("build_options");

const btn = @import("gui/widgets/button.zig");
const checkbox = @import("gui/widgets/checkbox.zig").checkbox;
const textInput = @import("gui/widgets/input.zig");
const GLRenderer = @import("gui/renderers/opengl.zig").GLRenderer;
const GuiContext = @import("gui/context.zig").GuiContext;
const shapes = @import("gui/shapes.zig");
const input = @import("gui/input.zig");
const c = @import("gui/c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub fn main() !void {
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1920, 1080, "zgui", null, null);
    if (window == null) {
        std.debug.print("Failed to create window", .{});
        return;
    }
    defer glfw.glfwDestroyWindow(window);

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

    var gui = try GuiContext.init(allocator, window);
    defer gui.deinit();

    glfw.glfwSetWindowUserPointer(window, &gui);
    _ = glfw.glfwSetMouseButtonCallback(window, input.mouseButtonCallback);
    _ = glfw.glfwSetCharCallback(window, input.charCallback);
    _ = glfw.glfwSetKeyCallback(window, input.keyCallback);
    _ = glfw.glfwSetScrollCallback(window, input.scrollCallback);

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glClearColor(0.55, 0.55, 0.55, 1.0);

    // FPS tracking (only if debug is enabled)
    var last_time: f64 = undefined;
    var fps: f64 = undefined;
    var fps_buffer: [32]u8 = undefined;
    if (build_options.debug) {
        last_time = glfw.glfwGetTime();
        fps = 0.0;
    }

    var box = false;

    var input_buffer: [256]u8 = undefined;
    var input_len: usize = 0;

    while (glfw.glfwWindowShouldClose(window) == 0) {
        gui.newFrame();

        glfw.glfwPollEvents();

        var fb_width: i32 = 0;
        var fb_height: i32 = 0;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        // calculate FPS
        if (build_options.debug) {
            const current_time = glfw.glfwGetTime();
            const delta_time = current_time - last_time;
            last_time = current_time;
            fps = 1.0 / delta_time;
        }

        gui.updateInput(window);

        if (try checkbox(&gui, 200, 200, &box, .{})) {
            std.debug.print("Toggled Checkbox to: {}\n", .{box});
        }

        if (try textInput.inputText(&gui, .{ .x = 300, .y = 170, .w = 300, .h = 40 }, &input_buffer, &input_len, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("Text changed: {s}\n", .{input_buffer[0..input_len]});
        }

        if (try btn.button(&gui, .{ .x = 0, .y = 0, .w = 200, .h = 50 }, "hello world", .{ .font_size = 24, .color = 0xFFC864FF, .border_radius = 10.0 })) {
            std.debug.print("Button 'hello world' was clicked!\n", .{});
        }
        if (box and try btn.button(&gui, .{ .x = 250, .y = 30, .w = 250, .h = 70 }, input_buffer[0..input_len], .{ .font_size = 36, .color = 0x64C8FFFF, .border_radius = 12.0 })) {
            std.debug.print("Button 'Large Text' was clicked!\n", .{});
        }
        if (try btn.button(&gui, .{ .x = 30, .y = 120, .w = 150, .h = 30 }, "small text", .{ .font_size = 16, .color = 0xC864FFFF, .border_radius = 8.0, .variant = btn.Variant.OUTLINED })) {
            std.debug.print("Button 'small text' was clicked!\n", .{});
        }

        const right_btn_rect = shapes.Rect{ .x = 30, .y = 250, .w = 200, .h = 50 };
        const right_is_hovered = gui.input.isMouseInRect(right_btn_rect);
        const right_color: u32 = if (right_is_hovered) 0xFF6464FF else 0xC86464FF;
        if (try btn.button(&gui, right_btn_rect, "Right Click Me", .{ .font_size = 20, .color = right_color, .border_radius = 10.0 })) {} // left click does nothing
        if (right_is_hovered and gui.input.mouse_right_clicked) {
            std.debug.print("Right mouse button clicked!\n", .{});
        }

        const middle_btn_rect = shapes.Rect{ .x = 250, .y = 250, .w = 200, .h = 50 };
        const middle_is_hovered = gui.input.isMouseInRect(middle_btn_rect);
        const middle_color: u32 = if (middle_is_hovered) 0x64FF64FF else 0x64C864FF;
        if (try btn.button(&gui, middle_btn_rect, "Middle Click Me", .{ .font_size = 20, .color = middle_color, .border_radius = 10.0 })) {} // left click does nothing
        if (middle_is_hovered and gui.input.mouse_middle_clicked) {
            std.debug.print("Middle mouse button clicked!\n", .{});
        }

        if (gui.input.scroll_y != 0) {
            std.debug.print("Scroll Y: {d:.2}\n", .{gui.input.scroll_y});
        }

        if (gui.input.scroll_x != 0) {
            std.debug.print("Scroll X: {d:.2}\n", .{gui.input.scroll_x});
        }

        if (build_options.debug) {
            const fps_text = try std.fmt.bufPrint(&fps_buffer, "{d:.0} FPS", .{fps});
            const fps_metrics = try gui.measureText(fps_text, 20);
            const fps_x = @as(f32, @floatFromInt(fb_width)) - fps_metrics.width - 60;
            const fps_y = 10;
            try gui.addText(fps_x, fps_y, fps_text, 36, 0xFFFFFFFF);
        }

        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gui.render(&renderer, fb_width, fb_height);

        glfw.glfwSwapBuffers(window);
    }

    // Process any remaining events to prevent crash on glfwTerminate
    glfw.glfwPollEvents();
}
