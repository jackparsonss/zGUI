const std = @import("std");
const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

pub const InputOptions = struct {
    font_size: f32 = 24,
    color: shapes.Color = 0x000000FF,
    text_color: shapes.Color = 0x000000FF,
    border_radius: f32 = 8.0,
    border_thickness: f32 = 2.0,
    max_length: usize = 256,
};

pub const InputState = struct {
    buffer: [256]u8,
    len: usize,
    cursor_pos: usize,
    is_focused: bool,
    cursor_blink_time: f64,
    scroll_offset: f32,

    pub fn init() InputState {
        return InputState{
            .buffer = undefined,
            .len = 0,
            .cursor_pos = 0,
            .is_focused = false,
            .cursor_blink_time = 0.0,
            .scroll_offset = 0.0,
        };
    }

    pub fn getText(self: *const InputState) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn clear(self: *InputState) void {
        self.len = 0;
        self.cursor_pos = 0;
    }
};

pub fn textInput(ctx: *GuiContext, rect: shapes.Rect, state: *InputState, opts: InputOptions) !bool {
    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    if (is_clicked) {
        state.is_focused = true;
        state.cursor_blink_time = glfw.glfwGetTime();
    } else if (ctx.input.mouse_left_clicked and !is_hovered) {
        state.is_focused = false;
    }

    var box_color = opts.color;
    if (state.is_focused) {
        const r: u8 = @intCast((opts.color >> 24) & 0xFF);
        const g: u8 = @intCast((opts.color >> 16) & 0xFF);
        const b: u8 = @intCast((opts.color >> 8) & 0xFF);
        const a: u8 = @intCast(opts.color & 0xFF);
        const factor = 1.2;
        const new_r: u8 = @min(255, @as(u8, @intFromFloat(@as(f32, @floatFromInt(r)) * factor)));
        const new_g: u8 = @min(255, @as(u8, @intFromFloat(@as(f32, @floatFromInt(g)) * factor)));
        const new_b: u8 = @min(255, @as(u8, @intFromFloat(@as(f32, @floatFromInt(b)) * factor)));
        box_color = (@as(u32, new_r) << 24) | (@as(u32, new_g) << 16) | (@as(u32, new_b) << 8) | @as(u32, a);
    }

    try ctx.draw_list.addRoundedRectOutline(rect, opts.border_radius, opts.border_thickness, box_color);

    var text_changed = false;
    if (state.is_focused) {
        for (0..ctx.input.chars_count) |i| {
            const char = ctx.input.chars_buffer[i];
            if (char >= 32 and char < 127 and state.len < opts.max_length and state.len < state.buffer.len) {
                if (state.cursor_pos < state.len) {
                    std.mem.copyBackwards(u8, state.buffer[state.cursor_pos + 1 .. state.len + 1], state.buffer[state.cursor_pos..state.len]);
                }
                state.buffer[state.cursor_pos] = @intCast(char);
                state.cursor_pos += 1;
                state.len += 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_BACKSPACE)) {
            if (state.cursor_pos > 0) {
                std.mem.copyForwards(u8, state.buffer[state.cursor_pos - 1 .. state.len - 1], state.buffer[state.cursor_pos..state.len]);
                state.cursor_pos -= 1;
                state.len -= 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_DELETE)) {
            if (state.cursor_pos < state.len) {
                std.mem.copyForwards(u8, state.buffer[state.cursor_pos .. state.len - 1], state.buffer[state.cursor_pos + 1 .. state.len]);
                state.len -= 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_LEFT)) {
            if (state.cursor_pos > 0) {
                state.cursor_pos -= 1;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_RIGHT)) {
            if (state.cursor_pos < state.len) {
                state.cursor_pos += 1;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_HOME)) {
            state.cursor_pos = 0;
            state.cursor_blink_time = glfw.glfwGetTime();
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_END)) {
            state.cursor_pos = state.len;
            state.cursor_blink_time = glfw.glfwGetTime();
        }
    }

    const padding = 8.0;
    const text_x = rect.x + padding;
    const text_y = rect.y + (rect.h - opts.font_size) * 0.5;
    const available_width = rect.w - (padding * 2.0);

    if (state.len > 0) {
        const text_before_cursor = state.buffer[0..state.cursor_pos];
        const metrics_to_cursor = try ctx.measureText(text_before_cursor, opts.font_size);
        const cursor_x_unscrolled = metrics_to_cursor.width;

        const cursor_margin = 10.0;
        if (cursor_x_unscrolled - state.scroll_offset > available_width - cursor_margin) {
            // Cursor is past the right edge, scroll right
            state.scroll_offset = cursor_x_unscrolled - available_width + cursor_margin;
        } else if (cursor_x_unscrolled - state.scroll_offset < cursor_margin) {
            // Cursor is past the left edge, scroll left
            state.scroll_offset = @max(0.0, cursor_x_unscrolled - cursor_margin);
        }
    } else {
        state.scroll_offset = 0.0;
    }

    if (state.len > 0) {
        const full_text = state.buffer[0..state.len];

        var visible_start: usize = 0;
        var visible_end: usize = state.len;
        var current_x: f32 = 0.0;

        for (0..state.len) |i| {
            const char_text = state.buffer[0 .. i + 1];
            const metrics = try ctx.measureText(char_text, opts.font_size);
            if (metrics.width >= state.scroll_offset) {
                visible_start = i;
                if (i > 0) {
                    const prev_metrics = try ctx.measureText(state.buffer[0..i], opts.font_size);
                    current_x = prev_metrics.width;
                }
                break;
            }
        }

        for (visible_start..state.len) |i| {
            const char_text = state.buffer[0 .. i + 1];
            const metrics = try ctx.measureText(char_text, opts.font_size);
            if (metrics.width - state.scroll_offset > available_width) {
                visible_end = i;
                break;
            }
        }

        if (visible_start < visible_end) {
            const visible_text = full_text[visible_start..visible_end];
            const render_x = text_x - (state.scroll_offset - current_x);
            try ctx.addText(render_x, text_y, visible_text, opts.font_size, opts.text_color);
        }
    }

    if (state.is_focused) {
        const current_time = glfw.glfwGetTime();
        const elapsed = current_time - state.cursor_blink_time;
        const blink_cycle = @mod(elapsed, 1.0);

        if (blink_cycle < 0.5) {
            var cursor_x = text_x;
            if (state.cursor_pos > 0) {
                const text_before_cursor = state.buffer[0..state.cursor_pos];
                const metrics = try ctx.measureText(text_before_cursor, opts.font_size);
                cursor_x = text_x + metrics.width - state.scroll_offset;
            }

            const cursor_height = opts.font_size;
            const cursor_y = rect.y + (rect.h - cursor_height) * 0.5;
            const cursor_rect = shapes.Rect{
                .x = cursor_x,
                .y = cursor_y,
                .w = 2.0,
                .h = cursor_height,
            };
            try ctx.draw_list.addRect(cursor_rect, opts.text_color);
        }
    }

    return text_changed;
}
