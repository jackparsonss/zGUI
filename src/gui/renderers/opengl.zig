const std = @import("std");
const gl = @import("../c.zig").glad;
const Vertex = @import("../shapes.zig").Vertex;
const DrawList = @import("../draw_list.zig").DrawList;

pub const GLRenderer = struct {
    shader: u32,
    vbo: u32,
    ibo: u32,
    vao: u32,

    pub fn init() GLRenderer {
        var self = GLRenderer{
            .shader = 0,
            .vbo = 0,
            .ibo = 0,
            .vao = 0,
        };

        self.shader = createShader();
        setupBuffers(&self);
        return self;
    }

    pub fn render(self: *GLRenderer, dl: *DrawList, width: i32, height: i32) void {
        gl.glUseProgram(self.shader);

        gl.glViewport(0, 0, width, height);

        const loc = gl.glGetUniformLocation(self.shader, "u_projection");
        var proj: [16]f32 = ortho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);
        gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, &proj);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(dl.vertices.items.len * @sizeOf(Vertex)), dl.vertices.items.ptr, gl.GL_DYNAMIC_DRAW);

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ibo);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(dl.indices.items.len * @sizeOf(Vertex)), dl.indices.items.ptr, gl.GL_DYNAMIC_DRAW);

        gl.glBindVertexArray(self.vao);
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(dl.indices.items.len), gl.GL_UNSIGNED_INT, null);
    }
};

fn setupBuffers(r: *GLRenderer) void {
    gl.glGenVertexArrays(1, &r.vao);
    gl.glGenBuffers(1, &r.vbo);
    gl.glGenBuffers(1, &r.ibo);

    gl.glBindVertexArray(r.vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, r.vbo);
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, r.ibo);

    const stride = @sizeOf(Vertex);

    gl.glEnableVertexAttribArray(0);
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(0));

    gl.glEnableVertexAttribArray(1);
    gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(8));

    gl.glEnableVertexAttribArray(2);
    gl.glVertexAttribPointer(2, 4, gl.GL_UNSIGNED_BYTE, gl.GL_TRUE, stride, @ptrFromInt(16));
}

fn createShader() u32 {
    const vs_src =
        \\#version 330 core
        \\layout (location = 0) in vec2 in_pos;
        \\layout (location = 1) in vec2 in_uv;
        \\layout (location = 2) in vec4 in_color;
        \\
        \\uniform mat4 u_projection;
        \\
        \\out vec4 vColor;
        \\
        \\void main() {
        \\    vColor = in_color;
        \\    gl_Position = u_projection * vec4(in_pos.xy, 0, 1);
        \\}
    ;

    const fs_src =
        \\#version 330 core
        \\in vec4 vColor;
        \\out vec4 out_color;
        \\void main() {
        \\    out_color = vColor;
        \\}
    ;

    const vs_ptrs = [_][*c]const u8{
        @ptrCast(vs_src),
    };

    const fs_ptrs = [_][*c]const u8{
        @ptrCast(fs_src),
    };

    const vs = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    const fs = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);

    gl.glShaderSource(vs, 1, &vs_ptrs, null);
    gl.glCompileShader(vs);

    gl.glShaderSource(fs, 1, &fs_ptrs, null);
    gl.glCompileShader(fs);

    const prog = gl.glCreateProgram();
    gl.glAttachShader(prog, vs);
    gl.glAttachShader(prog, fs);
    gl.glLinkProgram(prog);

    gl.glDeleteShader(vs);
    gl.glDeleteShader(fs);

    return prog;
}

// orthograpic projection
fn ortho(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) [16]f32 {
    return .{
        2 / (r - l),        0,                  0,                  0,
        0,                  2 / (t - b),        0,                  0,
        0,                  0,                  -2 / (f - n),       0,
        -(r + l) / (r - l), -(t + b) / (t - b), -(f + n) / (f - n), 1,
    };
}
