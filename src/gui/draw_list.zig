const std = @import("std");
const glad = @import("c.zig").glad;
const shapes = @import("shapes.zig");
const Font = @import("text/font.zig").Font;

pub const DrawList = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(shapes.Vertex),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) DrawList {
        return DrawList{
            .allocator = allocator,
            .vertices = .empty,
            .indices = .empty,
        };
    }

    pub fn clear(self: *DrawList) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
    }

    pub fn addVertex(self: *DrawList, v: shapes.Vertex) !void {
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.vertices.append(self.allocator, v);
        try self.indices.append(self.allocator, idx);
    }

    pub fn addTriangle(self: *DrawList, v1: shapes.Vertex, v2: shapes.Vertex, v3: shapes.Vertex) !void {
        try self.addVertex(v1);
        try self.addVertex(v2);
        try self.addVertex(v3);
    }

    pub fn addRect(self: *DrawList, rect: shapes.Rect, color: shapes.Color) !void {
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
    }

    pub fn addRectUV(
        self: *DrawList,
        rect: shapes.Rect,
        uv_min: [2]f32,
        uv_max: [2]f32,
        color: shapes.Color,
    ) !void {
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
    }

    pub fn addText(self: *DrawList, font: *const Font, x: f32, y: f32, text: []const u8, color: shapes.Color) !void {
        var cursor_x = x;
        const cursor_y = y + font.ascent * font.scale;

        for (text) |c| {
            const glyph_index: usize = @intCast(c);
            const g = font.glyphs[glyph_index];

            const gx0 = cursor_x + g.x_off * font.scale;
            const gy0 = cursor_y + g.y_off * font.scale;
            const gx1 = gx0 + (@as(f32, @floatFromInt(g.x1 - g.x0)) * font.scale);
            const gy1 = gy0 + (@as(f32, @floatFromInt(g.y1 - g.y0)) * font.scale);

            const uv_min = .{
                @as(f32, @floatFromInt(g.x0)) / @as(f32, @floatFromInt(font.tex_width)),
                @as(f32, @floatFromInt(g.y0)) / @as(f32, @floatFromInt(font.tex_height)),
            };

            const uv_max = .{
                @as(f32, @floatFromInt(g.x1)) / @as(f32, @floatFromInt(font.tex_width)),
                @as(f32, @floatFromInt(g.y1)) / @as(f32, @floatFromInt(font.tex_height)),
            };

            try self.addRectUV(.{ .x = gx0, .y = gy0, .w = gx1 - gx0, .h = gy1 - gy0 }, uv_min, uv_max, color);

            cursor_x += g.x_advance * font.scale;
        }
    }

    pub fn deinit(self: *DrawList) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
    }
};
