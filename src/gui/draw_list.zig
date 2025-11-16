const std = @import("std");
const glad = @import("c.zig").glad;
const shapes = @import("shapes.zig");

pub const Vertex = struct {
    pos: [2]f32,
    color: shapes.Color,
};

pub const DrawList = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vertex),
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

    pub fn addVertex(self: *DrawList, v: Vertex) !void {
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.vertices.append(self.allocator, v);
        try self.indices.append(self.allocator, idx);
    }

    pub fn addTriangle(self: *DrawList, v1: Vertex, v2: Vertex, v3: Vertex) !void {
        try self.addVertex(v1);
        try self.addVertex(v2);
        try self.addVertex(v3);
    }

    pub fn addRect(self: *DrawList, rect: shapes.Rect, color: shapes.Color) !void {
        const v1 = Vertex{ .pos = .{ rect.x, rect.y }, .color = color };
        const v2 = Vertex{ .pos = .{ rect.x + rect.w, rect.y }, .color = color };
        const v3 = Vertex{ .pos = .{ rect.x + rect.w, rect.y + rect.h }, .color = color };
        const v4 = Vertex{ .pos = .{ rect.x, rect.y + rect.h }, .color = color };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &[_]Vertex{ v1, v2, v3, v4 });
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
