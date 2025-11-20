const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

fn darkenColor(color: shapes.Color, factor: f32) shapes.Color {
    const r: u8 = @intCast((color >> 24) & 0xFF);
    const g: u8 = @intCast((color >> 16) & 0xFF);
    const b: u8 = @intCast((color >> 8) & 0xFF);
    const a: u8 = @intCast(color & 0xFF);

    const new_r: u8 = @intFromFloat(@as(f32, @floatFromInt(r)) * factor);
    const new_g: u8 = @intFromFloat(@as(f32, @floatFromInt(g)) * factor);
    const new_b: u8 = @intFromFloat(@as(f32, @floatFromInt(b)) * factor);

    return (@as(u32, new_r) << 24) | (@as(u32, new_g) << 16) | (@as(u32, new_b) << 8) | @as(u32, a);
}

pub fn button(ctx: *GuiContext, rect: shapes.Rect, label: []const u8, font_size: f32, color: shapes.Color, corner_radius: f32) !bool {
    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    var button_color = color;
    if (is_hovered and ctx.input.mouse_left_pressed) {
        button_color = darkenColor(color, 0.8);
    } else if (is_hovered) {
        button_color = darkenColor(color, 0.9);
    }

    try ctx.draw_list.addRoundedRect(rect, corner_radius, button_color);

    const metrics = try ctx.measureText(label, font_size);

    const tx = rect.x + (rect.w - metrics.width) * 0.5;
    const ty = rect.y + (rect.h - metrics.height) * 0.5;

    try ctx.addText(tx, ty, label, font_size, 0x000000FF);

    return is_clicked;
}
