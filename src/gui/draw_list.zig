const std = @import("std");
const glad = @import("c.zig").glad;

pub const Vertex = struct {
    pos: [2]f32,
    color: [4]f32,
};

pub const DrawList = struct {
    vertices: []Vertex,

    pub fn init() DrawList {
        return DrawList{
            .vertices = &[_]Vertex{},
        };
    }

    pub fn clear(self: *DrawList) void {
        self.vertices = &[_]Vertex{};
    }

    pub fn flush(self: *DrawList) void {
        for (self.vertices) |v| {
            glad.glBegin(glad.GL_POINTS);
            glad.glColor4f(v.color[0], v.color[1], v.color[2], v.color[3]);
            glad.glVertex2f(v.pos[0], v.pos[1]);
        }
    }

    // pub fn deinit(self: *DrawList) void {}
};
