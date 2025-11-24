const std = @import("std");
const GuiContext = @import("context.zig").GuiContext;
const shapes = @import("shapes.zig");

pub const Direction = enum {
    HORIZONTAL,
    VERTICAL,
};

pub const LayoutOptions = struct {
    margin: f32 = 0.0,
    padding: f32 = 0.0,
    width: ?f32 = null, // Fixed width (null = auto)
    height: ?f32 = null, // Fixed height (null = auto)
};

pub const Layout = struct {
    direction: Direction,
    x: f32,
    y: f32,
    current_x: f32,
    current_y: f32,
    margin: f32,
    padding: f32,
    max_cross_size: f32, // max height for horizontal, max width for vertical
    is_first_widget: bool, // Track if this is the first widget to avoid margin
    width: ?f32, // Fixed width (null = auto)
    height: ?f32, // Fixed height (null = auto)

    pub fn init(direction: Direction, x: f32, y: f32, opts: LayoutOptions) Layout {
        return Layout{
            .direction = direction,
            .x = x,
            .y = y,
            .current_x = x + opts.padding,
            .current_y = y + opts.padding,
            .margin = opts.margin,
            .padding = opts.padding,
            .max_cross_size = 0.0,
            .is_first_widget = true,
            .width = opts.width,
            .height = opts.height,
        };
    }

    pub fn allocateSpace(self: *Layout, width: f32, height: f32) shapes.Rect {
        if (!self.is_first_widget) {
            switch (self.direction) {
                .HORIZONTAL => self.current_x += self.margin,
                .VERTICAL => self.current_y += self.margin,
            }
        }
        self.is_first_widget = false;

        const rect = shapes.Rect{
            .x = self.current_x,
            .y = self.current_y,
            .w = width,
            .h = height,
        };

        switch (self.direction) {
            .HORIZONTAL => {
                self.current_x += width;
                self.max_cross_size = @max(self.max_cross_size, height);
            },
            .VERTICAL => {
                self.current_y += height;
                self.max_cross_size = @max(self.max_cross_size, width);
            },
        }

        return rect;
    }

    pub fn getCurrentPos(self: *const Layout) struct { x: f32, y: f32 } {
        return .{ .x = self.current_x, .y = self.current_y };
    }

    pub fn skip(self: *Layout, amount: f32) void {
        switch (self.direction) {
            .HORIZONTAL => self.current_x += amount,
            .VERTICAL => self.current_y += amount,
        }
    }
};

pub fn getBounds(layout: *const Layout) shapes.Rect {
    const auto_width = switch (layout.direction) {
        .HORIZONTAL => layout.current_x - layout.x + layout.padding,
        .VERTICAL => layout.max_cross_size + layout.padding * 2,
    };
    const auto_height = switch (layout.direction) {
        .HORIZONTAL => layout.max_cross_size + layout.padding * 2,
        .VERTICAL => layout.current_y - layout.y + layout.padding,
    };

    return shapes.Rect{
        .x = layout.x,
        .y = layout.y,
        .w = layout.width orelse auto_width,
        .h = layout.height orelse auto_height,
    };
}

pub fn hLayout(ctx: *GuiContext, opts: LayoutOptions) Layout {
    return layoutHelper(ctx, .HORIZONTAL, opts);
}

pub fn vLayout(ctx: *GuiContext, opts: LayoutOptions) Layout {
    return layoutHelper(ctx, .VERTICAL, opts);
}

fn layoutHelper(ctx: *GuiContext, direction: Direction, opts: LayoutOptions) Layout {
    var layout_opts = opts;
    var x: f32 = 0;
    var y: f32 = 0;

    if (ctx.getCurrentLayout()) |parent| {
        const width: f32 = opts.width orelse 100; // default for auto-sizing
        const height: f32 = opts.height orelse 100;

        const rect = parent.allocateSpace(width, height);
        x = rect.x;
        y = rect.y;
    } else {
        const pos = ctx.getNextLayoutPos();
        x = pos.x;
        y = pos.y;
        if (layout_opts.width == null) {
            layout_opts.width = ctx.window_width;
        }
        if (layout_opts.height == null) {
            layout_opts.height = ctx.window_height;
        }
    }

    return Layout.init(direction, x, y, layout_opts);
}

pub fn beginLayout(ctx: *GuiContext, layout: Layout) !void {
    try ctx.layout_stack.append(ctx.allocator, layout);
}

pub fn endLayout(ctx: *GuiContext) void {
    if (ctx.layout_stack.items.len == 0) return;

    const finished_layout_opt = ctx.layout_stack.pop();
    const finished_layout = finished_layout_opt orelse return;

    const bounds = getBounds(&finished_layout);
    ctx.updateLayoutPos(bounds);
}
