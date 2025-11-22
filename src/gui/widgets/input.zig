const builtin = @import("builtin");
const std = @import("std");
const GuiContext = @import("../context.zig").GuiContext;
const ActiveInputState = @import("../context.zig").ActiveInputState;
const shapes = @import("../shapes.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

pub const InputOptions = struct {
    font_size: f32 = 24,
    color: shapes.Color = 0x000000FF,
    text_color: shapes.Color = 0x000000FF,
    border_radius: f32 = 8.0,
    border_thickness: f32 = 2.0,
};

fn isWordBoundary(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\n' or char == '.' or char == ',' or
        char == ';' or char == ':' or char == '!' or char == '?' or char == '(' or
        char == ')' or char == '[' or char == ']' or char == '{' or char == '}' or
        char == '-' or char == '_' or char == '/' or char == '\\';
}

fn findPreviousWordBoundary(buffer: []const u8, cursor_pos: usize) usize {
    if (cursor_pos == 0) return 0;

    var pos = cursor_pos;

    // Skip any whitespace/punctuation at current position
    while (pos > 0 and isWordBoundary(buffer[pos - 1])) {
        pos -= 1;
    }

    // Move back to the start of the word
    while (pos > 0 and !isWordBoundary(buffer[pos - 1])) {
        pos -= 1;
    }

    return pos;
}

fn findNextWordBoundary(buffer: []const u8, len: usize, cursor_pos: usize) usize {
    if (cursor_pos >= len) return len;

    var pos = cursor_pos;

    // Skip any whitespace/punctuation at current position
    while (pos < len and isWordBoundary(buffer[pos])) {
        pos += 1;
    }

    // Move forward to the end of the word
    while (pos < len and !isWordBoundary(buffer[pos])) {
        pos += 1;
    }

    return pos;
}

fn hasSelection(state: *const ActiveInputState, cursor_pos: usize) bool {
    return state.selection_start != null and state.selection_start.? != cursor_pos;
}

fn getSelectionRange(state: *const ActiveInputState, cursor_pos: usize) ?struct { start: usize, end: usize } {
    if (state.selection_start) |sel_start| {
        if (sel_start != cursor_pos) {
            const start = @min(sel_start, cursor_pos);
            const end = @max(sel_start, cursor_pos);
            return .{ .start = start, .end = end };
        }
    }
    return null;
}

pub fn inputText(ctx: *GuiContext, rect: shapes.Rect, buffer: []u8, buffer_len: *usize, opts: InputOptions) !bool {
    const id = @intFromPtr(buffer.ptr);

    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    const is_active = if (ctx.active_input_id) |active_id| active_id == id else false;

    var state = if (is_active and ctx.active_input_state != null)
        ctx.active_input_state.?
    else
        ActiveInputState.init();

    if (!is_active and is_clicked) {
        state.cursor_pos = buffer_len.*;
    }

    if (is_clicked) {
        ctx.active_input_id = id;
        state.cursor_blink_time = glfw.glfwGetTime();
    } else if (ctx.input.mouse_left_clicked and !is_hovered and is_active) {
        ctx.active_input_id = null;
        ctx.active_input_state = null;
        return false;
    }

    var box_color = opts.color;
    if (is_active) {
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
    if (is_active) {
        for (0..ctx.input.chars_count) |i| {
            const char = ctx.input.chars_buffer[i];
            if (char >= 32 and char < 127 and buffer_len.* < buffer.len) {
                // Delete selection if it exists
                if (hasSelection(&state, state.cursor_pos)) {
                    if (getSelectionRange(&state, state.cursor_pos)) |range| {
                        const bytes_to_remove = range.end - range.start;
                        std.mem.copyForwards(u8, buffer[range.start .. buffer_len.* - bytes_to_remove], buffer[range.end..buffer_len.*]);
                        buffer_len.* -= bytes_to_remove;
                        state.cursor_pos = range.start;
                        state.selection_start = null;
                        text_changed = true;
                    }
                }

                if (state.cursor_pos < buffer_len.*) {
                    std.mem.copyBackwards(u8, buffer[state.cursor_pos + 1 .. buffer_len.* + 1], buffer[state.cursor_pos..buffer_len.*]);
                }
                buffer[state.cursor_pos] = @intCast(char);
                state.cursor_pos += 1;
                buffer_len.* += 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_BACKSPACE)) {
            if (hasSelection(&state, state.cursor_pos)) {
                if (getSelectionRange(&state, state.cursor_pos)) |range| {
                    const bytes_to_remove = range.end - range.start;
                    std.mem.copyForwards(u8, buffer[range.start .. buffer_len.* - bytes_to_remove], buffer[range.end..buffer_len.*]);
                    buffer_len.* -= bytes_to_remove;
                    state.cursor_pos = range.start;
                    state.selection_start = null;
                    text_changed = true;
                    state.cursor_blink_time = glfw.glfwGetTime();
                }
            } else if (state.cursor_pos > 0) {
                std.mem.copyForwards(u8, buffer[state.cursor_pos - 1 .. buffer_len.* - 1], buffer[state.cursor_pos..buffer_len.*]);
                state.cursor_pos -= 1;
                buffer_len.* -= 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_DELETE)) {
            if (hasSelection(&state, state.cursor_pos)) {
                if (getSelectionRange(&state, state.cursor_pos)) |range| {
                    const bytes_to_remove = range.end - range.start;
                    std.mem.copyForwards(u8, buffer[range.start .. buffer_len.* - bytes_to_remove], buffer[range.end..buffer_len.*]);
                    buffer_len.* -= bytes_to_remove;
                    state.cursor_pos = range.start;
                    state.selection_start = null;
                    text_changed = true;
                    state.cursor_blink_time = glfw.glfwGetTime();
                }
            } else if (state.cursor_pos < buffer_len.*) {
                std.mem.copyForwards(u8, buffer[state.cursor_pos .. buffer_len.* - 1], buffer[state.cursor_pos + 1 .. buffer_len.*]);
                buffer_len.* -= 1;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_LEFT)) {
            if (ctx.input.shift_pressed and state.selection_start == null) {
                state.selection_start = state.cursor_pos;
            }

            var new_pos: usize = state.cursor_pos;
            if (ctx.input.super_pressed) {
                // Command (Mac) / Super + Left: jump to start
                new_pos = 0;
            } else if (ctx.input.alt_pressed or ctx.input.ctrl_pressed) {
                // Option/Alt/Control + Left: jump to previous word
                new_pos = findPreviousWordBoundary(buffer[0..buffer_len.*], state.cursor_pos);
            } else {
                // Normal left arrow: move one character
                if (hasSelection(&state, state.cursor_pos) and !ctx.input.shift_pressed) {
                    // If there's a selection and Shift is not pressed, move to start of selection
                    if (getSelectionRange(&state, state.cursor_pos)) |range| {
                        new_pos = range.start;
                    }
                } else if (state.cursor_pos > 0) {
                    new_pos = state.cursor_pos - 1;
                }
            }

            state.cursor_pos = new_pos;
            state.cursor_blink_time = glfw.glfwGetTime();

            if (!ctx.input.shift_pressed) {
                state.selection_start = null;
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_RIGHT)) {
            if (ctx.input.shift_pressed and state.selection_start == null) {
                state.selection_start = state.cursor_pos;
            }

            var new_pos: usize = state.cursor_pos;
            if (ctx.input.super_pressed) {
                // Command (Mac) / Super + Right: jump to end
                new_pos = buffer_len.*;
            } else if (ctx.input.alt_pressed or ctx.input.ctrl_pressed) {
                // Option/Alt/Control + Right: jump to next word
                new_pos = findNextWordBoundary(buffer[0..buffer_len.*], buffer_len.*, state.cursor_pos);
            } else {
                if (hasSelection(&state, state.cursor_pos) and !ctx.input.shift_pressed) {
                    if (getSelectionRange(&state, state.cursor_pos)) |range| {
                        new_pos = range.end;
                    }
                } else if (state.cursor_pos < buffer_len.*) {
                    new_pos = state.cursor_pos + 1;
                }
            }

            state.cursor_pos = new_pos;
            state.cursor_blink_time = glfw.glfwGetTime();

            if (!ctx.input.shift_pressed) {
                state.selection_start = null;
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_HOME)) {
            if (ctx.input.shift_pressed and state.selection_start == null) {
                state.selection_start = state.cursor_pos;
            }
            state.cursor_pos = 0;
            state.cursor_blink_time = glfw.glfwGetTime();
            if (!ctx.input.shift_pressed) {
                state.selection_start = null;
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_END)) {
            if (ctx.input.shift_pressed and state.selection_start == null) {
                state.selection_start = state.cursor_pos;
            }
            state.cursor_pos = buffer_len.*;
            state.cursor_blink_time = glfw.glfwGetTime();
            if (!ctx.input.shift_pressed) {
                state.selection_start = null;
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_V) and ctx.input.primary_pressed) {
            const content = glfw.glfwGetClipboardString(ctx.window);
            if (content != null) {
                const len = std.mem.len(content);
                const slice = content[0..len];

                // Delete selection if it exists
                if (hasSelection(&state, state.cursor_pos)) {
                    if (getSelectionRange(&state, state.cursor_pos)) |range| {
                        const bytes_to_remove = range.end - range.start;
                        std.mem.copyForwards(u8, buffer[range.start .. buffer_len.* - bytes_to_remove], buffer[range.end..buffer_len.*]);
                        buffer_len.* -= bytes_to_remove;
                        state.cursor_pos = range.start;
                        state.selection_start = null;
                        text_changed = true;
                    }
                }

                // Check if we have enough space in the buffer
                if (buffer_len.* + len <= buffer.len) {
                    // Make room for the pasted text by shifting existing text to the right
                    if (state.cursor_pos < buffer_len.*) {
                        std.mem.copyBackwards(
                            u8,
                            buffer[state.cursor_pos + len .. buffer_len.* + len],
                            buffer[state.cursor_pos..buffer_len.*],
                        );
                    }

                    // Insert the pasted content
                    std.mem.copyForwards(
                        u8,
                        buffer[state.cursor_pos .. state.cursor_pos + len],
                        slice,
                    );

                    state.cursor_pos += len;
                    buffer_len.* += len;
                    text_changed = true;
                    state.cursor_blink_time = glfw.glfwGetTime();
                }
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_C) and ctx.input.primary_pressed and hasSelection(&state, state.cursor_pos)) {
            if (getSelectionRange(&state, state.cursor_pos)) |range| {
                const content = buffer[range.start..range.end];

                var buf: [4096:0]u8 = undefined;
                const copy_len = @min(content.len, buf.len - 1);
                @memcpy(buf[0..copy_len], content[0..copy_len]);
                buf[copy_len] = 0;

                glfw.glfwSetClipboardString(ctx.window, &buf);
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_X) and ctx.input.primary_pressed and hasSelection(&state, state.cursor_pos)) {
            if (getSelectionRange(&state, state.cursor_pos)) |range| {
                const content = buffer[range.start..range.end];

                var buf: [4096:0]u8 = undefined;
                const copy_len = @min(content.len, buf.len - 1);
                @memcpy(buf[0..copy_len], content[0..copy_len]);
                buf[copy_len] = 0;

                glfw.glfwSetClipboardString(ctx.window, &buf);

                // Delete the selection after copying
                const bytes_to_remove = range.end - range.start;
                std.mem.copyForwards(u8, buffer[range.start .. buffer_len.* - bytes_to_remove], buffer[range.end..buffer_len.*]);
                buffer_len.* -= bytes_to_remove;
                state.cursor_pos = range.start;
                state.selection_start = null;
                text_changed = true;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }

        if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_A) and ctx.input.primary_pressed) {
            // Select all text
            if (buffer_len.* > 0) {
                state.selection_start = 0;
                state.cursor_pos = buffer_len.*;
                state.cursor_blink_time = glfw.glfwGetTime();
            }
        }
    }

    const padding = 8.0;
    const text_x = rect.x + padding;
    const text_y = rect.y + (rect.h - opts.font_size) * 0.5;
    const available_width = rect.w - (padding * 2.0);

    if (buffer_len.* > 0) {
        const text_before_cursor = buffer[0..state.cursor_pos];
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

    if (buffer_len.* > 0) {
        const full_text = buffer[0..buffer_len.*];

        var visible_start: usize = 0;
        var visible_end: usize = buffer_len.*;
        var current_x: f32 = 0.0;

        for (0..buffer_len.*) |i| {
            const char_text = buffer[0 .. i + 1];
            const metrics = try ctx.measureText(char_text, opts.font_size);
            if (metrics.width >= state.scroll_offset) {
                visible_start = i;
                if (i > 0) {
                    const prev_metrics = try ctx.measureText(buffer[0..i], opts.font_size);
                    current_x = prev_metrics.width;
                }
                break;
            }
        }

        for (visible_start..buffer_len.*) |i| {
            const char_text = buffer[0 .. i + 1];
            const metrics = try ctx.measureText(char_text, opts.font_size);
            if (metrics.width - state.scroll_offset > available_width) {
                visible_end = i;
                break;
            }
        }

        if (getSelectionRange(&state, state.cursor_pos)) |sel_range| {
            const text_before_sel_start = buffer[0..sel_range.start];
            const text_before_sel_end = buffer[0..sel_range.end];

            const metrics_start = try ctx.measureText(text_before_sel_start, opts.font_size);
            const metrics_end = try ctx.measureText(text_before_sel_end, opts.font_size);

            const sel_x_start = text_x + metrics_start.width - state.scroll_offset;
            const sel_x_end = text_x + metrics_end.width - state.scroll_offset;

            if (sel_x_end >= text_x and sel_x_start <= text_x + available_width) {
                const highlight_x = @max(sel_x_start, rect.x);
                const highlight_w = @min(sel_x_end, rect.x + rect.w - padding) - highlight_x;

                if (highlight_w > 0) {
                    const selection_color: u32 = 0x4A90E2AA; // Semi-transparent blue
                    const selection_rect = shapes.Rect{
                        .x = highlight_x,
                        .y = text_y,
                        .w = highlight_w,
                        .h = opts.font_size,
                    };
                    try ctx.draw_list.addRect(selection_rect, selection_color);
                }
            }
        }

        if (visible_start < visible_end) {
            const visible_text = full_text[visible_start..visible_end];
            const render_x = text_x - (state.scroll_offset - current_x);
            try ctx.addText(render_x, text_y, visible_text, opts.font_size, opts.text_color);
        }
    }

    if (is_active) {
        const current_time = glfw.glfwGetTime();
        const elapsed = current_time - state.cursor_blink_time;
        const blink_cycle = @mod(elapsed, 1.0);

        if (blink_cycle < 0.5) {
            var cursor_x = text_x;
            if (state.cursor_pos > 0) {
                const text_before_cursor = buffer[0..state.cursor_pos];
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

    if (is_active) {
        ctx.active_input_state = state;
    }

    return text_changed;
}
