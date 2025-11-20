const std = @import("std");
const glad = @import("c.zig").glad;
const shapes = @import("shapes.zig");
const Font = @import("text/font.zig").Font;

pub const DrawCmd = struct {
    texture: u32,
    elem_count: u32,
    index_offset: u32,
};

pub const DrawList = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(shapes.Vertex),
    indices: std.ArrayList(u32),
    commands: std.ArrayList(DrawCmd),
    current_texture: u32,

    pub fn init(allocator: std.mem.Allocator) DrawList {
        return DrawList{
            .allocator = allocator,
            .vertices = .empty,
            .indices = .empty,
            .commands = .empty,
            .current_texture = 0,
        };
    }

    pub fn clear(self: *DrawList) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.commands.clearRetainingCapacity();
        self.current_texture = 0;
    }

    pub fn setTexture(self: *DrawList, texture: u32) !void {
        if (texture != self.current_texture) {
            self.current_texture = texture;
            // Start a new draw command for this texture
            if (self.commands.items.len > 0) {
                // Close the previous command
                const prev_cmd = &self.commands.items[self.commands.items.len - 1];
                const current_index: u32 = @intCast(self.indices.items.len);
                prev_cmd.elem_count = current_index - prev_cmd.index_offset;
            }
            // Add new command
            try self.commands.append(self.allocator, DrawCmd{
                .texture = texture,
                .elem_count = 0,
                .index_offset = @intCast(self.indices.items.len),
            });
        }
    }

    fn ensureDrawCmd(self: *DrawList) !void {
        if (self.commands.items.len == 0) {
            try self.commands.append(self.allocator, DrawCmd{
                .texture = self.current_texture,
                .elem_count = 0,
                .index_offset = 0,
            });
        }
    }

    fn updateCurrentCmd(self: *DrawList) void {
        if (self.commands.items.len > 0) {
            const cmd = &self.commands.items[self.commands.items.len - 1];
            const current_index: u32 = @intCast(self.indices.items.len);
            cmd.elem_count = current_index - cmd.index_offset;
        }
    }

    pub fn addVertex(self: *DrawList, v: shapes.Vertex) !void {
        try self.ensureDrawCmd();
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.vertices.append(self.allocator, v);
        try self.indices.append(self.allocator, idx);
        self.updateCurrentCmd();
    }

    pub fn addTriangle(self: *DrawList, v1: shapes.Vertex, v2: shapes.Vertex, v3: shapes.Vertex) !void {
        try self.ensureDrawCmd();
        try self.addVertex(v1);
        try self.addVertex(v2);
        try self.addVertex(v3);
    }

    pub fn addRect(self: *DrawList, rect: shapes.Rect, color: shapes.Color) !void {
        try self.ensureDrawCmd();
        const v1 = shapes.Vertex{ .pos = .{ rect.x, rect.y }, .color = color };
        const v2 = shapes.Vertex{ .pos = .{ rect.x + rect.w, rect.y }, .color = color };
        const v3 = shapes.Vertex{ .pos = .{ rect.x + rect.w, rect.y + rect.h }, .color = color };
        const v4 = shapes.Vertex{ .pos = .{ rect.x, rect.y + rect.h }, .color = color };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &[_]shapes.Vertex{ v1, v2, v3, v4 });
        try self.indices.appendSlice(self.allocator, &[_]u32{
            base, base + 1, base + 2,
            base, base + 2, base + 3,
        });
        self.updateCurrentCmd();
    }

    pub fn addRectUV(
        self: *DrawList,
        rect: shapes.Rect,
        uv_min: [2]f32,
        uv_max: [2]f32,
        color: shapes.Color,
    ) !void {
        try self.ensureDrawCmd();
        const x1 = rect.x;
        const y1 = rect.y;
        const x2 = rect.x + rect.w;
        const y2 = rect.y + rect.h;

        const uv1 = uv_min[0];
        const v1 = uv_min[1];
        const uv2 = uv_max[0];
        const v2 = uv_max[1];

        const vtx = [_]shapes.Vertex{
            .{ .pos = .{ x1, y1 }, .uv = .{ uv1, v1 }, .color = color },
            .{ .pos = .{ x2, y1 }, .uv = .{ uv2, v1 }, .color = color },
            .{ .pos = .{ x2, y2 }, .uv = .{ uv2, v2 }, .color = color },
            .{ .pos = .{ x1, y2 }, .uv = .{ uv1, v2 }, .color = color },
        };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &vtx);

        try self.indices.appendSlice(self.allocator, &[_]u32{
            base, base + 1, base + 2,
            base, base + 2, base + 3,
        });
        self.updateCurrentCmd();
    }

    pub fn addText(self: *DrawList, font: *const Font, x: f32, y: f32, text: []const u8, color: shapes.Color) !void {
        var cursor_x = x;
        const cursor_y = y + font.ascent;

        for (text) |c| {
            const glyph_index: usize = @intCast(c);
            const g = font.glyphs[glyph_index];

            const gx0 = cursor_x + g.x_off;
            const gy0 = cursor_y + g.y_off;
            const gx1 = gx0 + (@as(f32, @floatFromInt(g.x1 - g.x0)));
            const gy1 = gy0 + (@as(f32, @floatFromInt(g.y1 - g.y0)));

            try self.addRectUV(.{ .x = gx0, .y = gy0, .w = gx1 - gx0, .h = gy1 - gy0 }, g.uv0, g.uv1, color);

            cursor_x += g.x_advance;
        }
    }

    pub fn deinit(self: *DrawList) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.commands.deinit(self.allocator);
    }
};
