const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");
const layout = @import("../layout.zig");

pub const Options = struct {
    color: shapes.Color = 0x404040FF,
    border_radius: f32 = 0.0,
};

pub fn panel(ctx: *GuiContext, opts: Options) !void {
    const current_layout = ctx.assertCurrentLayout();
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
}
