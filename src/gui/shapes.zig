pub const Color = [4]u8;
pub const Vertex = struct {
    pos: [2]f32,
    uv: [2]f32 = .{ 1.0, 0.0 },
    color: Color = .{ 255, 255, 255, 1 },
};

pub const Rect = struct { x: f32, y: f32, w: f32, h: f32 };
