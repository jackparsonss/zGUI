const std = @import("std");
const glad = @import("c.zig").glad;
const shapes = @import("shapes.zig");

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

    pub fn deinit(self: *DrawList) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
    }
};
