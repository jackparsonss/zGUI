const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

pub fn button(ctx: *GuiContext, rect: shapes.Rect, label: []const u8, color: shapes.Color) !bool {
    try ctx.draw_list.addRect(rect, color);

    const metrics = ctx.font.measure(label);

    const tx = rect.x + (rect.w - metrics.width) * 0.5;
    const ty = rect.y + (rect.h - metrics.height) * 0.5;

    try ctx.draw_list.addText(&ctx.font, tx, ty, label, .{ 255, 255, 255, 1 });

    return false;
}
