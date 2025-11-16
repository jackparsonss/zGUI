pub const Color = u32;
pub const Vertex = struct {
    pos: [2]f32,
    uv: [2]f32 = .{ 0.0, 0.0 },
    color: Color = 0xffffffff,
};

pub const Rect = struct { x: f32, y: f32, w: f32, h: f32 };
