const std = @import("std");
const build_options = @import("build_options");

const btn = @import("gui/widgets/button.zig");
const checkbox = @import("gui/widgets/checkbox.zig").checkbox;
const textInput = @import("gui/widgets/input.zig");
const imageWidget = @import("gui/widgets/image.zig");
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

    // Load test image
    var checkmark_img = try imageWidget.Image.load(allocator, "assets/checkmark.png");
    defer checkmark_img.deinit();

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

    var f32_value: f32 = 42.5;
    var f64_value: f64 = 3.14159265359;
    var i32_value: i32 = -123;
    var i64_value: i64 = 9876543210;

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

        try imageWidget.image(&gui, 50, 300, &checkmark_img, .{});

        if (try checkbox(&gui, 200, 200, &box, .{})) {
            std.debug.print("Toggled Checkbox to: {}\n", .{box});
        }

        if (try textInput.inputText(&gui, .{ .x = 300, .y = 170, .w = 300, .h = 40 }, &input_buffer, &input_len, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("Text changed: {s}\n", .{input_buffer[0..input_len]});
        }

        if (try textInput.inputNumber(&gui, .{ .x = 600, .y = 220, .w = 200, .h = 40 }, &f32_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("F32 changed: {d}\n", .{f32_value});
        }

        if (try textInput.inputNumber(&gui, .{ .x = 600, .y = 270, .w = 200, .h = 40 }, &f64_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("F64 changed: {d}\n", .{f64_value});
        }

        if (try textInput.inputNumber(&gui, .{ .x = 810, .y = 220, .w = 150, .h = 40 }, &i32_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("I32 changed: {d}\n", .{i32_value});
        }

        if (try textInput.inputNumber(&gui, .{ .x = 810, .y = 270, .w = 150, .h = 40 }, &i64_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0x000000FF })) {
            std.debug.print("I64 changed: {d}\n", .{i64_value});
        }

        if (try btn.button(&gui, 0, 0, "hello world", .{ .font_size = 24, .color = 0xFFC864FF, .border_radius = 10.0 })) {
            std.debug.print("Button 'hello world' was clicked!\n", .{});
        }
        if (box and try btn.button(&gui, 250, 30, input_buffer[0..input_len], .{ .font_size = 36, .color = 0x64C8FFFF, .border_radius = 12.0 })) {
            std.debug.print("Button 'Large Text' was clicked!\n", .{});
        }
        if (try btn.button(&gui, 30, 120, "small text", .{ .font_size = 16, .color = 0xC864FFFF, .border_radius = 8.0, .variant = btn.Variant.OUTLINED })) {
            std.debug.print("Button 'small text' was clicked!\n", .{});
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
