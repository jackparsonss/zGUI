const std = @import("std");

const GuiContext = @import("context.zig").GuiContext;
const shapes = @import("shapes.zig");
const c = @import("c.zig");
const Window = c.Window;
const glfw = c.glfw;

pub fn mouseButtonCallback(window: c.Window, btn: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    const gui_ptr = glfw.glfwGetWindowUserPointer(window);
    if (gui_ptr != null) {
        const gui: *GuiContext = @ptrCast(@alignCast(gui_ptr));
        gui.handleMouseButton(btn, action);
    }
}

pub const Input = struct {
    cursor_x: f64,
    cursor_y: f64,
    mouse_left_pressed: bool,
    mouse_left_clicked: bool,
    mouse_left_click_count: u32,

    pub fn init() Input {
        return Input{
            .cursor_x = 0,
            .cursor_y = 0,
            .mouse_left_pressed = false,
            .mouse_left_clicked = false,
            .mouse_left_click_count = 0,
        };
    }

    pub fn beginFrame(self: *Input) void {
        self.mouse_left_clicked = self.mouse_left_click_count > 0;
        self.mouse_left_click_count = 0;
    }

    pub fn registerMouseClick(self: *Input) void {
        self.mouse_left_click_count += 1;
    }

    pub fn update(self: *Input, window: Window) void {
        // Update cursor position in window coordinates
        var window_x: f64 = 0;
        var window_y: f64 = 0;
        glfw.glfwGetCursorPos(window, &window_x, &window_y);

        // Get window size and framebuffer size to calculate scale
        var window_width: i32 = 0;
        var window_height: i32 = 0;
        var fb_width: i32 = 0;
        var fb_height: i32 = 0;
        glfw.glfwGetWindowSize(window, &window_width, &window_height);
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        // Convert from window coordinates to framebuffer coordinates
        const scale_x = @as(f64, @floatFromInt(fb_width)) / @as(f64, @floatFromInt(window_width));
        const scale_y = @as(f64, @floatFromInt(fb_height)) / @as(f64, @floatFromInt(window_height));
        self.cursor_x = window_x * scale_x;
        self.cursor_y = window_y * scale_y;

        // Update mouse button state (for potential future use like drag detection)
        const current_state = glfw.glfwGetMouseButton(window, glfw.GLFW_MOUSE_BUTTON_LEFT);
        self.mouse_left_pressed = (current_state == glfw.GLFW_PRESS);
    }

    pub fn isMouseInRect(self: *const Input, rect: shapes.Rect) bool {
        const mx = @as(f32, @floatCast(self.cursor_x));
        const my = @as(f32, @floatCast(self.cursor_y));
        return mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h;
    }
};
