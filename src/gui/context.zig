const std = @import("std");
const Font = @import("text/font.zig").Font;
const DrawList = @import("draw_list.zig").DrawList;
const GLRenderer = @import("renderers/opengl.zig").GLRenderer;

pub const CursorPosition = struct { x: f64, y: f64 };

pub const GuiContext = struct {
    draw_list: DrawList,
    cursor_pos: CursorPosition,
    font: Font,

    pub fn init(allocator: std.mem.Allocator) !GuiContext {
        return GuiContext{
            .draw_list = DrawList.init(allocator),
            .cursor_pos = CursorPosition{ .x = 0, .y = 0 },
            .font = try Font.load(allocator, "src/gui/text/RobotoMono-Regular.ttf", 18),
        };
    }

    pub fn newFrame(self: *GuiContext) void {
        self.draw_list.clear();
    }

    pub fn render(self: *GuiContext, renderer: *GLRenderer, width: i32, height: i32) void {
        renderer.render(self, width, height);
    }

    pub fn deinit(self: *GuiContext) void {
        self.draw_list.deinit();
    }
};
