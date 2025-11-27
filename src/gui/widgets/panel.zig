const ResizeBorder = @import("../context.zig").ResizeBorder;
const GuiContext = @import("../context.zig").GuiContext;
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
    const current_layout = ctx.getCurrentLayout();
    const panel_id = ctx.id_counter;
    ctx.id_counter += 1;

    if (opts.resizable) {
        ctx.current_panel_id = panel_id;
    }

    if (ctx.panel_sizes.get(panel_id)) |stored_size| {
        if (stored_size.width) |w| {
            current_layout.width = w;
        }
        if (stored_size.height) |h| {
            current_layout.height = h;
        }
        // Apply position offsets
        current_layout.x += stored_size.x_offset;
        current_layout.y += stored_size.y_offset;
        current_layout.current_x = current_layout.x + current_layout.padding;
        current_layout.current_y = current_layout.y + current_layout.padding;
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
            const current_offsets = ctx.panel_sizes.get(panel_id) orelse PanelSize{
                .width = null,
                .height = null,
                .min_width = 100.0,
                .min_height = 100.0,
                .x_offset = 0.0,
                .y_offset = 0.0,
            };

            ctx.resize_state.dragging = true;
            ctx.resize_state.panel_id = panel_id;
            ctx.resize_state.border = hover_border.?;
            ctx.resize_state.initial_mouse_pos = switch (hover_border.?) {
                .left, .right => mouse_x,
                .top, .bottom => mouse_y,
            };
            ctx.resize_state.panel_rect = rect;
            ctx.resize_state.initial_x_offset = current_offsets.x_offset;
            ctx.resize_state.initial_y_offset = current_offsets.y_offset;
        }

        if (ctx.resize_state.dragging and ctx.resize_state.panel_id == panel_id) {
            const is_dragging = ctx.input.mouse_left_pressed;

            if (is_dragging) {
                const current_pos = switch (ctx.resize_state.border) {
                    .left, .right => mouse_x,
                    .top, .bottom => mouse_y,
                };
                const delta = current_pos - ctx.resize_state.initial_mouse_pos;

                const stored_size = ctx.panel_sizes.get(panel_id) orelse PanelSize{
                    .width = null,
                    .height = null,
                    .min_width = 100.0,
                    .min_height = 100.0,
                    .x_offset = 0.0,
                    .y_offset = 0.0,
                };
                switch (ctx.resize_state.border) {
                    .right => {
                        const new_width = ctx.resize_state.panel_rect.w + delta;
                        if (new_width >= stored_size.min_width) {
                            current_layout.width = new_width;
                            try ctx.panel_sizes.put(panel_id, .{
                                .width = new_width,
                                .height = current_layout.height,
                                .min_width = stored_size.min_width,
                                .min_height = stored_size.min_height,
                                .x_offset = stored_size.x_offset,
                                .y_offset = stored_size.y_offset,
                            });
                        }
                    },
                    .left => {
                        const new_width = ctx.resize_state.panel_rect.w - delta;
                        if (new_width >= stored_size.min_width) {
                            const new_offset = ctx.resize_state.initial_x_offset + delta;
                            current_layout.width = new_width;
                            try ctx.panel_sizes.put(panel_id, .{
                                .width = new_width,
                                .height = current_layout.height,
                                .min_width = stored_size.min_width,
                                .min_height = stored_size.min_height,
                                .x_offset = new_offset,
                                .y_offset = stored_size.y_offset,
                            });
                        }
                    },
                    .bottom => {
                        const new_height = ctx.resize_state.panel_rect.h + delta;
                        if (new_height >= stored_size.min_height) {
                            current_layout.height = new_height;
                            try ctx.panel_sizes.put(panel_id, .{
                                .width = current_layout.width,
                                .height = new_height,
                                .min_width = stored_size.min_width,
                                .min_height = stored_size.min_height,
                                .x_offset = stored_size.x_offset,
                                .y_offset = stored_size.y_offset,
                            });
                        }
                    },
                    .top => {
                        const new_height = ctx.resize_state.panel_rect.h - delta;
                        if (new_height >= stored_size.min_height) {
                            const new_offset = ctx.resize_state.initial_y_offset + delta;
                            current_layout.height = new_height;
                            try ctx.panel_sizes.put(panel_id, .{
                                .width = current_layout.width,
                                .height = new_height,
                                .min_width = stored_size.min_width,
                                .min_height = stored_size.min_height,
                                .x_offset = stored_size.x_offset,
                                .y_offset = new_offset,
                            });
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
