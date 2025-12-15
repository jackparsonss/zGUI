const std = @import("std");
const build_options = @import("build_options");

const btn = @import("gui/widgets/button.zig");
const checkbox = @import("gui/widgets/checkbox.zig").checkbox;
const textInput = @import("gui/widgets/input.zig");
const imageWidget = @import("gui/widgets/image.zig");
const panelWidget = @import("gui/widgets/panel.zig");
const dropdown = @import("gui/widgets/dropdown.zig");
const collapsible = @import("gui/widgets/collapsible.zig");
const layout = @import("gui/layout.zig");
const GLRenderer = @import("gui/renderers/opengl.zig").GLRenderer;
const GuiContext = @import("gui/context.zig").GuiContext;
const shapes = @import("gui/shapes.zig");
const input = @import("gui/input.zig");
const DebugStats = @import("gui/debug_stats.zig").DebugStats;
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
    _ = glfw.glfwSetFramebufferSizeCallback(window, input.framebufferSizeCallback);

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glClearColor(0.55, 0.55, 0.55, 1.0);

    var debug_stats = if (comptime build_options.debug) DebugStats.init() else {};
    defer {
        if (comptime build_options.debug) {
            debug_stats.deinit();
        }
    }
    var stats_buffer: [128]u8 = undefined;

    var box = false;

    var input_buffer: [256]u8 = undefined;
    var input_len: usize = 0;

    var left_section_open = true;
    var right_section_open = true;

    var left_panel_width: f32 = 250;
    var right_panel_width: f32 = 350;
    var bottom_panel_height: f32 = 300;

    var f32_value: f32 = 42.5;
    var f64_value: f64 = 3.14159265359;
    var i32_value: i32 = -123;
    var i64_value: i64 = 9876543210;

    var fb_width: i32 = 0;
    var fb_height: i32 = 0;
    glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
    gui.setWindowSize(@floatFromInt(fb_width), @floatFromInt(fb_height));

    const file_options = [_][]const u8{ "New", "Open", "Save", "Save As", "Exit" };
    const menu_options = [_][]const u8{ "Preferences", "Settings", "About" };
    const top_panel_height: f32 = 40;

    while (glfw.glfwWindowShouldClose(window) == 0) {
        if (comptime build_options.debug) {
            debug_stats.beginFrame(glfw.glfwGetTime());
        }

        gui.newFrame();
        glfw.glfwPollEvents();
        gui.updateInput(window);
        if (gui.is_resizing) {
            continue;
        }

        const center_width = gui.window_width - left_panel_width - right_panel_width;

        layout.beginLayout(&gui, layout.vLayout(&gui, .{ .margin = 0, .padding = 0, .height = gui.window_height }));

        layout.beginLayout(&gui, layout.hLayout(&gui, .{ .margin = 10, .padding = 12, .height = top_panel_height }));
        _ = try panelWidget.topPanel(&gui, "top", .{ .resizable = false });

        if (try dropdown.dropdown(&gui, 1, "File", &file_options, .{ .font_size = 16, .padding = 6, .color = 0x546be7FF, .border_radius = 4.0, .font_color = 0xFFFFFFFF })) |index| {
            std.debug.print("File option selected: {s}\n", .{file_options[index]});
        }

        if (try dropdown.dropdown(&gui, 2, "Menu", &menu_options, .{ .font_size = 16, .padding = 6, .color = 0x546be7FF, .border_radius = 4.0, .font_color = 0xFFFFFFFF })) |index| {
            std.debug.print("Menu option selected: {s}\n", .{menu_options[index]});
        }

        layout.endLayout(&gui);

        // Main content area - horizontal layout
        layout.beginLayout(&gui, layout.hLayout(&gui, .{ .margin = 0, .padding = 0, .height = gui.window_height - top_panel_height }));

        // Left sidebar - vertical layout with buttons and checkbox (left aligned)
        layout.beginLayout(&gui, layout.vLayout(&gui, .{ .margin = 10, .padding = 20, .width = left_panel_width }));
        const left_panel = try panelWidget.leftPanel(&gui, "left", .{ .resizable = true });
        left_panel_width = left_panel.width;

        if (try collapsible.collapsibleSection(&gui, "Buttons", &left_section_open, .{})) {
            if (btn.button(&gui, "hello world", .{ .font_size = 24, .color = 0xFFC864FF, .border_radius = 10.0 })) {
                std.debug.print("Button 'hello world' was clicked!\n", .{});
            }
            if (btn.button(&gui, "small text", .{ .font_size = 16, .font_color = 0xFFFFFFFF, .color = 0xC864FFFF, .border_radius = 8.0, .variant = btn.Variant.OUTLINED })) {
                std.debug.print("Button 'small text' was clicked!\n", .{});
            }
            if (box and btn.button(&gui, input_buffer[0..input_len], .{ .font_size = 36, .color = 0x64C8FFFF, .border_radius = 12.0 })) {
                std.debug.print("Button 'Large Text' was clicked!\n", .{});
            }
            if (try checkbox(&gui, &box, .{})) {
                std.debug.print("Toggled Checkbox to: {}\n", .{box});
            }
            layout.endLayout(&gui);
        }
        layout.endLayout(&gui);

        // Center column - new vertical layout container

        layout.beginLayout(&gui, layout.vLayout(&gui, .{
            .padding = 0,
            .width = center_width,
        }));

        // Image widget - centered within vertical layout (leaves room for bottom panel)
        layout.beginLayout(&gui, layout.vLayout(&gui, .{
            .padding = 0,
            .width = center_width,
            .height = gui.window_height - bottom_panel_height,
            .align_horizontal = .CENTER,
            .align_vertical = .CENTER,
        }));
        try imageWidget.image(&gui, &checkmark_img, .{});
        layout.endLayout(&gui);

        // Bottom panel - sibling to image container, follows sequentially
        layout.beginLayout(&gui, layout.hLayout(&gui, .{
            .margin = 0,
            .padding = 0,
            .height = bottom_panel_height,
            .width = center_width,
        }));
        const bottom_panel = try panelWidget.bottomPanel(&gui, "bottom", .{ .resizable = true });
        bottom_panel_height = bottom_panel.height;
        layout.endLayout(&gui);

        layout.endLayout(&gui); // End center column vLayout

        // Right sidebar - vertical layout with input fields (bottom aligned)
        layout.beginLayout(&gui, layout.vLayout(&gui, .{ .margin = 10, .padding = 20, .width = right_panel_width }));
        const right_panel = try panelWidget.rightPanel(&gui, "right", .{ .resizable = true });
        right_panel_width = right_panel.width;

        if (try collapsible.collapsibleSection(&gui, "Inputs", &right_section_open, .{})) {
            if (try textInput.inputText(&gui, &input_buffer, &input_len, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0xFFFFFFFF, .width = 300, .height = 40 })) {
                std.debug.print("Text changed: {s}\n", .{input_buffer[0..input_len]});
            }
            if (try textInput.inputNumber(&gui, &f32_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0xFFFFFFFF, .width = 300, .height = 40 })) {
                std.debug.print("F32 changed: {d}\n", .{f32_value});
            }
            if (try textInput.inputNumber(&gui, &f64_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0xFFFFFFFF, .width = 300, .height = 40 })) {
                std.debug.print("F64 changed: {d}\n", .{f64_value});
            }
            if (try textInput.inputNumber(&gui, &i32_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0xFFFFFFFF, .width = 300, .height = 40 })) {
                std.debug.print("I32 changed: {d}\n", .{i32_value});
            }
            if (try textInput.inputNumber(&gui, &i64_value, .{ .font_size = 20, .color = 0x666666FF, .text_color = 0xFFFFFFFF, .width = 300, .height = 40 })) {
                std.debug.print("I64 changed: {d}\n", .{i64_value});
            }
            layout.endLayout(&gui);
        }
        layout.endLayout(&gui);

        layout.endLayout(&gui); // End main content area horizontal layout
        layout.endLayout(&gui); // End outer vertical layout

        if (comptime build_options.debug) {
            const stats_text = try debug_stats.format(&stats_buffer);
            const stats_metrics = try gui.measureText(stats_text, 20);
            const stats_x = gui.window_width - stats_metrics.width - 10;
            const stats_y = 10;
            try gui.addText(stats_x, stats_y, stats_text, 20, 0xFFFFFFFF);
        }

        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gui.render(&renderer, @intFromFloat(gui.window_width), @intFromFloat(gui.window_height));

        if (comptime build_options.debug) {
            debug_stats.endFrame();
        }

        glfw.glfwSwapBuffers(window);
    }

    // Process any remaining events to prevent crash on glfwTerminate
    glfw.glfwPollEvents();
}
