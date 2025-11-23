const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");
const imageWidget = @import("image.zig");

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

    try ctx.draw_list.addRoundedRectOutline(rect, opts.border_radius, opts.border_thickness, opts.color);
    if (checked.*) {
        const padding = opts.size * 0.15;
        const checkmark_size = opts.size - (padding * 2);
        const checkmark_x = x + padding;
        const checkmark_y = y + padding;

        try imageWidget.image(ctx, checkmark_x, checkmark_y, &ctx.checkmark_image, .{
            .width = checkmark_size,
            .height = checkmark_size,
        });
    }

    return is_clicked;
}
