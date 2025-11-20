const std = @import("std");
const FontCache = @import("text/font_cache.zig").FontCache;
const TextMetrics = @import("text/font.zig").TextMetrics;
const DrawList = @import("draw_list.zig").DrawList;
const GLRenderer = @import("renderers/opengl.zig").GLRenderer;
const shapes = @import("shapes.zig");

pub const CursorPosition = struct { x: f64, y: f64 };

pub const GuiContext = struct {
    draw_list: DrawList,
    cursor_pos: CursorPosition,
    font_cache: FontCache,
    current_font_texture: u32,

    pub fn init(allocator: std.mem.Allocator) !GuiContext {
        return GuiContext{
            .draw_list = DrawList.init(allocator),
            .cursor_pos = CursorPosition{ .x = 0, .y = 0 },
            .font_cache = FontCache.init(allocator, "src/gui/text/RobotoMono-Regular.ttf"),
            .current_font_texture = 0,
        };
    }

    pub fn newFrame(self: *GuiContext) void {
        self.draw_list.clear();
    }

    pub fn render(self: *GuiContext, renderer: *GLRenderer, width: i32, height: i32) void {
        renderer.render(self, width, height);
    }

    pub fn measureText(self: *GuiContext, text: []const u8, font_size: f32) !TextMetrics {
        const font = try self.font_cache.getFont(font_size);
        return font.measure(text);
    }

    pub fn addText(self: *GuiContext, x: f32, y: f32, text: []const u8, font_size: f32, color: shapes.Color) !void {
        const font = try self.font_cache.getFont(font_size);
        self.current_font_texture = font.texture;
        try self.draw_list.setTexture(font.texture);
        try self.draw_list.addText(font, x, y, text, color);
    }

    pub fn deinit(self: *GuiContext) void {
        self.draw_list.deinit();
        self.font_cache.deinit();
    }
};
