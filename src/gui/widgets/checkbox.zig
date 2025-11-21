const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

pub const CheckboxOptions = struct {
    size: f32 = 24.0,
    color: shapes.Color = 0x000000FF,
    border_radius: f32 = 4.0,
    border_thickness: f32 = 2.0,
};

pub fn checkbox(ctx: *GuiContext, x: f32, y: f32, checked: *bool, opts: CheckboxOptions) !bool {
    const rect = shapes.Rect{
        .x = x,
        .y = y,
        .w = opts.size,
        .h = opts.size,
    };

    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    if (is_clicked) {
        checked.* = !checked.*;
    }

    if (checked.*) {
        // Draw filled rounded rect
        try ctx.draw_list.addRoundedRect(rect, opts.border_radius, opts.color);
    } else {
        // Draw outlined rounded rect
        try ctx.draw_list.addRoundedRectOutline(rect, opts.border_radius, opts.border_thickness, opts.color);
    }

    return is_clicked;
}
