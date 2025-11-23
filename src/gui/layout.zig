const std = @import("std");
const GuiContext = @import("context.zig").GuiContext;
const shapes = @import("shapes.zig");

pub const Direction = enum {
    HORIZONTAL,
    VERTICAL,
};

pub const LayoutOptions = struct {
    spacing: f32 = 0.0,
};

pub const Layout = struct {
    direction: Direction,
    x: f32,
    y: f32,
    current_x: f32,
    current_y: f32,
    spacing: f32,
    max_cross_size: f32, // max height for horizontal, max width for vertical

    pub fn init(direction: Direction, x: f32, y: f32, opts: LayoutOptions) Layout {
        return Layout{
            .direction = direction,
            .x = x,
            .y = y,
            .current_x = x,
            .current_y = y,
            .spacing = opts.spacing,
            .max_cross_size = 0.0,
        };
    }

    pub fn allocateSpace(self: *Layout, width: f32, height: f32) shapes.Rect {
        const rect = shapes.Rect{
            .x = self.current_x,
            .y = self.current_y,
            .w = width,
            .h = height,
        };

        switch (self.direction) {
            .HORIZONTAL => {
                self.current_x += width + self.spacing;
                self.max_cross_size = @max(self.max_cross_size, height);
            },
            .VERTICAL => {
                self.current_y += height + self.spacing;
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

// Convenience functions for creating layouts
pub fn hLayout(x: f32, y: f32, opts: LayoutOptions) Layout {
    return Layout.init(.HORIZONTAL, x, y, opts);
}

pub fn vLayout(x: f32, y: f32, opts: LayoutOptions) Layout {
    return Layout.init(.VERTICAL, x, y, opts);
}

// Helper to push a layout onto the context's layout stack
pub fn beginLayout(ctx: *GuiContext, layout: Layout) !void {
    try ctx.layout_stack.append(ctx.allocator, layout);
}

// Helper to pop a layout from the context's layout stack
pub fn endLayout(ctx: *GuiContext) void {
    _ = ctx.layout_stack.pop();
}
