const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

pub fn button(ctx: *GuiContext, rect: shapes.Rect, label: []const u8, font_size: f32, color: shapes.Color, corner_radius: f32) !bool {
    try ctx.draw_list.addRoundedRect(rect, corner_radius, color);

    const metrics = try ctx.measureText(label, font_size);

    const tx = rect.x + (rect.w - metrics.width) * 0.5;
    const ty = rect.y + (rect.h - metrics.height) * 0.5;

    try ctx.addText(tx, ty, label, font_size, 0x000000FF);

    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    return is_clicked;
}
