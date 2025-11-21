const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

fn darkenColor(color: shapes.Color, factor: f32) shapes.Color {
    const r: f32 = @floatFromInt((color >> 24) & 0xFF);
    const g: f32 = @floatFromInt((color >> 16) & 0xFF);
    const b: f32 = @floatFromInt((color >> 8) & 0xFF);
    const a: u8 = @intCast(color & 0xFF);

    const new_r: u8 = @intFromFloat(r * factor);
    const new_g: u8 = @intFromFloat(g * factor);
    const new_b: u8 = @intFromFloat(b * factor);

    return (@as(u32, new_r) << 24) | (@as(u32, new_g) << 16) | (@as(u32, new_b) << 8) | @as(u32, a);
}

pub const ButtonOptions = struct {
    font_size: f32 = 24,
    color: shapes.Color = 0x000000FF,
    border_radius: f32 = 8.0,
};

pub fn button(ctx: *GuiContext, rect: shapes.Rect, label: []const u8, opts: ButtonOptions) !bool {
    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    var button_color = opts.color;
    if (is_hovered and ctx.input.mouse_left_pressed) {
        button_color = darkenColor(opts.color, 0.8);
    } else if (is_hovered) {
        button_color = darkenColor(opts.color, 0.9);
    }

    try ctx.draw_list.addRoundedRect(rect, opts.border_radius, button_color);

    const metrics = try ctx.measureText(label, opts.font_size);

    const tx = rect.x + (rect.w - metrics.width) * 0.5;
    const ty = rect.y + (rect.h - metrics.height) * 0.5;

    try ctx.addText(tx, ty, label, opts.font_size, 0x000000FF);

    return is_clicked;
}
