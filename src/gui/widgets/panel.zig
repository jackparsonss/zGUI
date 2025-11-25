const GuiContext = @import("../context.zig").GuiContext;
const ResizeBorder = @import("../context.zig").ResizeBorder;
const PanelSize = @import("../context.zig").PanelSize;
const shapes = @import("../shapes.zig");
const layout = @import("../layout.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

const highlight_color: shapes.Color = 0x00AAFFFF;

pub const Options = struct {
    color: shapes.Color = 0x404040FF,
    border_radius: f32 = 0.0,
    resizable: bool = false,
};

pub const PanelResult = struct {
    width: f32,
    height: f32,
};

pub fn panel(ctx: *GuiContext, opts: Options) !PanelResult {
    const current_layout = ctx.assertCurrentLayout();

    const panel_id = @as(u64, @intFromFloat(current_layout.x * 10000 + current_layout.y + @as(f32, @floatFromInt(ctx.layout_stack.items.len))));

    if (ctx.panel_sizes.get(panel_id)) |stored_size| {
        if (stored_size.width) |w| {
            current_layout.width = w;
        }
        if (stored_size.height) |h| {
            current_layout.height = h;
        }
    }

    const full_height = current_layout.height orelse ctx.window_height;
    const full_width = current_layout.width orelse ctx.window_width;
    const rect = shapes.Rect{
        .x = current_layout.x,
        .y = current_layout.y,
        .w = full_width,
        .h = full_height,
    };

    if (opts.border_radius > 0.0) {
        try ctx.draw_list.addRoundedRect(rect, opts.border_radius, opts.color);
    } else {
        try ctx.draw_list.addRect(rect, opts.color);
    }

    if (opts.resizable) {
        const border_width: f32 = 10.0;
        const mouse_x: f32 = @floatCast(ctx.input.cursor_x);
        const mouse_y: f32 = @floatCast(ctx.input.cursor_y);

        var hover_border: ?ResizeBorder = null;

        // VLayout can only resize horizontally (left/right borders)
        // HLayout can only resize vertically (top/bottom borders)
        const allow_horizontal = current_layout.direction == .VERTICAL;
        const allow_vertical = current_layout.direction == .HORIZONTAL;

        if (allow_horizontal and
            mouse_x >= rect.x + rect.w - border_width and
            mouse_x <= rect.x + rect.w and
            mouse_y >= rect.y and mouse_y <= rect.y + rect.h)
        {
            hover_border = .right;
        } else if (allow_horizontal and
            mouse_x >= rect.x and
            mouse_x <= rect.x + border_width and
            mouse_y >= rect.y and mouse_y <= rect.y + rect.h)
        {
            hover_border = .left;
        } else if (allow_vertical and
            mouse_y >= rect.y + rect.h - border_width and
            mouse_y <= rect.y + rect.h and
            mouse_x >= rect.x and mouse_x <= rect.x + rect.w)
        {
            hover_border = .bottom;
        } else if (allow_vertical and
            mouse_y >= rect.y and
            mouse_y <= rect.y + border_width and
            mouse_x >= rect.x and mouse_x <= rect.x + rect.w)
        {
            hover_border = .top;
        }

        if (hover_border != null and ctx.input.mouse_left_clicked) {
            ctx.resize_state.dragging = true;
            ctx.resize_state.panel_id = panel_id;
            ctx.resize_state.border = hover_border.?;
            ctx.resize_state.initial_mouse_pos = switch (hover_border.?) {
                .left, .right => mouse_x,
                .top, .bottom => mouse_y,
            };
            ctx.resize_state.panel_rect = rect;
        }

        if (ctx.resize_state.dragging and ctx.resize_state.panel_id == panel_id) {
            const is_dragging = ctx.input.mouse_left_pressed;

            if (is_dragging) {
                const current_pos = switch (ctx.resize_state.border) {
                    .left, .right => mouse_x,
                    .top, .bottom => mouse_y,
                };
                const delta = current_pos - ctx.resize_state.initial_mouse_pos;

                switch (ctx.resize_state.border) {
                    .right => {
                        const new_width = ctx.resize_state.panel_rect.w + delta;
                        if (new_width > 100.0) {
                            current_layout.width = new_width;
                            try ctx.panel_sizes.put(panel_id, .{ .width = new_width, .height = current_layout.height });
                        }
                    },
                    .left => {
                        const new_width = ctx.resize_state.panel_rect.w - delta;
                        if (new_width > 100.0) {
                            current_layout.width = new_width;
                            try ctx.panel_sizes.put(panel_id, .{ .width = new_width, .height = current_layout.height });
                        }
                    },
                    .bottom => {
                        const new_height = ctx.resize_state.panel_rect.h + delta;
                        if (new_height > 100.0) {
                            current_layout.height = new_height;
                            try ctx.panel_sizes.put(panel_id, .{ .width = current_layout.width, .height = new_height });
                        }
                    },
                    .top => {
                        const new_height = ctx.resize_state.panel_rect.h - delta;
                        if (new_height > 100.0) {
                            current_layout.height = new_height;
                            try ctx.panel_sizes.put(panel_id, .{ .width = current_layout.width, .height = new_height });
                        }
                    },
                }

                hover_border = ctx.resize_state.border;
            } else {
                ctx.resize_state.dragging = false;
            }
        }

        if (hover_border != null and (ctx.resize_state.dragging == false or
            (ctx.resize_state.dragging and ctx.resize_state.panel_id == panel_id)))
        {
            // Set appropriate cursor based on border
            const cursor = switch (hover_border.?) {
                .left, .right => ctx.hresize_cursor,
                .top, .bottom => ctx.vresize_cursor,
            };
            ctx.setCursor(cursor);

            const highlight_rect = switch (hover_border.?) {
                .right => shapes.Rect{
                    .x = rect.x + rect.w - 2.0,
                    .y = rect.y,
                    .w = 2.0,
                    .h = rect.h,
                },
                .left => shapes.Rect{
                    .x = rect.x,
                    .y = rect.y,
                    .w = 2.0,
                    .h = rect.h,
                },
                .bottom => shapes.Rect{
                    .x = rect.x,
                    .y = rect.y + rect.h - 2.0,
                    .w = rect.w,
                    .h = 2.0,
                },
                .top => shapes.Rect{
                    .x = rect.x,
                    .y = rect.y,
                    .w = rect.w,
                    .h = 2.0,
                },
            };
            try ctx.draw_list.addRect(highlight_rect, highlight_color);
        }
    }

    return PanelResult{
        .width = full_width,
        .height = full_height,
    };
}
