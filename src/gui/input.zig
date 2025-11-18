const std = @import("std");

const c = @import("c.zig");
const Window = c.Window;
const glfw = c.glfw;

const gui = @import("context.zig");

pub fn updateInput(ctx: *gui.GuiContext, window: Window) void {
    glfw.glfwGetCursorPos(window, &ctx.cursor_pos.x, &ctx.cursor_pos.y);
    // std.debug.print("Cursor Position: x={}, y={}\n", .{ ctx.cursor_pos.x, ctx.cursor_pos.y });
}
