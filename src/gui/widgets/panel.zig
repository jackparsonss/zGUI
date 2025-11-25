const GuiContext = @import("../context.zig").GuiContext;
const ResizeBorder = @import("../context.zig").ResizeBorder;
const PanelSize = @import("../context.zig").PanelSize;
const shapes = @import("../shapes.zig");
const layout = @import("../layout.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

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

    // Generate unique ID for this panel based on layout stack depth and position
    const panel_id = @as(u64, @intFromFloat(current_layout.x * 10000 + current_layout.y + @as(f32, @floatFromInt(ctx.layout_stack.items.len))));

    // Apply stored panel size if it exists
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

    // Draw the panel background
    if (opts.border_radius > 0.0) {
        try ctx.draw_list.addRoundedRect(rect, opts.border_radius, opts.color);
    } else {
        try ctx.draw_list.addRect(rect, opts.color);
    }

    // Handle resizable borders
    if (opts.resizable) {
        const border_width: f32 = 6.0; // Width of the resize handle area
        const mouse_x: f32 = @floatCast(ctx.input.cursor_x);
        const mouse_y: f32 = @floatCast(ctx.input.cursor_y);

        // Check which border we're near (if any)
        var hover_border: ?ResizeBorder = null;

        // Check right border
        if (mouse_x >= rect.x + rect.w - border_width and
            mouse_x <= rect.x + rect.w and
            mouse_y >= rect.y and mouse_y <= rect.y + rect.h) {
            hover_border = .right;
        }
        // Check left border
        else if (mouse_x >= rect.x and
                 mouse_x <= rect.x + border_width and
                 mouse_y >= rect.y and mouse_y <= rect.y + rect.h) {
            hover_border = .left;
        }
        // Check bottom border
        else if (mouse_y >= rect.y + rect.h - border_width and
                 mouse_y <= rect.y + rect.h and
                 mouse_x >= rect.x and mouse_x <= rect.x + rect.w) {
            hover_border = .bottom;
        }
        // Check top border
        else if (mouse_y >= rect.y and
                 mouse_y <= rect.y + border_width and
                 mouse_x >= rect.x and mouse_x <= rect.x + rect.w) {
            hover_border = .top;
        }

        // Handle drag start
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

        // Handle dragging
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
                        if (new_width > 100.0) { // Minimum width
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
                        if (new_height > 100.0) { // Minimum height
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

                // Draw highlight while dragging
                hover_border = ctx.resize_state.border;
            } else {
                // Mouse released, stop dragging
                ctx.resize_state.dragging = false;
            }
        }

        // Draw border highlight if hovering or dragging this panel
        if (hover_border != null and (ctx.resize_state.dragging == false or
            (ctx.resize_state.dragging and ctx.resize_state.panel_id == panel_id))) {
            const highlight_color: shapes.Color = 0x00AAFFFF; // Bright blue
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
