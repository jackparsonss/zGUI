const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");

pub fn button(ctx: *GuiContext, rect: shapes.Rect, color: shapes.Color) !bool {
    try ctx.draw_list.addRect(rect, color);

    return false;
}
