const std = @import("std");
const gl = @import("../c.zig").glad;
const GuiContext = @import("../context.zig").GuiContext;
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

    pub fn render(self: *GLRenderer, ctx: *GuiContext, width: i32, height: i32) void {
        const dl = &ctx.draw_list;
        if (dl.vertices.items.len == 0 or dl.commands.items.len == 0) {
            return;
        }

        gl.glUseProgram(self.shader);
        checkGlError("glUseProgram");

        gl.glViewport(0, 0, width, height);
        checkGlError("glViewport");

        const loc = gl.glGetUniformLocation(self.shader, "u_projection");
        checkGlError("glGetUniformLocation");
        var proj: [16]f32 = ortho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);
        gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, &proj);
        checkGlError("glUniformMatrix4fv");

        const tex_loc = gl.glGetUniformLocation(self.shader, "uTexture");
        gl.glUniform1i(tex_loc, 0);
        checkGlError("glUniform1i");

        // Bind VAO first, then upload vertex and index data
        gl.glBindVertexArray(self.vao);
        checkGlError("glBindVertexArray render");

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
        checkGlError("glBindBuffer vbo render");
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(dl.vertices.items.len * @sizeOf(Vertex)), dl.vertices.items.ptr, gl.GL_DYNAMIC_DRAW);
        checkGlError("glBufferData vbo");

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ibo);
        checkGlError("glBindBuffer ibo render");
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(dl.indices.items.len * @sizeOf(u32)), dl.indices.items.ptr, gl.GL_DYNAMIC_DRAW);
        checkGlError("glBufferData ibo");

        gl.glActiveTexture(gl.GL_TEXTURE0);

        for (dl.commands.items) |cmd| {
            if (cmd.elem_count == 0) continue;

            // Only bind texture if it's valid (non-zero)
            // Shader handles non-textured geometry via UV coordinates
            if (cmd.texture != 0) {
                gl.glBindTexture(gl.GL_TEXTURE_2D, cmd.texture);
                checkGlError("glBindTexture");
            }

            const offset_ptr: ?*const anyopaque = @ptrFromInt(cmd.index_offset * @sizeOf(u32));
            gl.glDrawElements(gl.GL_TRIANGLES, @intCast(cmd.elem_count), gl.GL_UNSIGNED_INT, offset_ptr);
            checkGlError("glDrawElements");
        }
    }
};

fn setupBuffers(r: *GLRenderer) void {
    gl.glGenVertexArrays(1, &r.vao);
    checkGlError("glGenVertexArrays");
    gl.glGenBuffers(1, &r.vbo);
    checkGlError("glGenBuffers vbo");
    gl.glGenBuffers(1, &r.ibo);
    checkGlError("glGenBuffers ibo");

    gl.glBindVertexArray(r.vao);
    checkGlError("glBindVertexArray");
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, r.vbo);
    checkGlError("glBindBuffer vbo");
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, r.ibo);
    checkGlError("glBindBuffer ibo");

    const stride = @sizeOf(Vertex);

    gl.glEnableVertexAttribArray(0);
    checkGlError("glEnableVertexAttribArray 0");
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(0));
    checkGlError("glVertexAttribPointer 0");

    gl.glEnableVertexAttribArray(1);
    checkGlError("glEnableVertexAttribArray 1");
    gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(8));
    checkGlError("glVertexAttribPointer 1");

    gl.glEnableVertexAttribArray(2);
    checkGlError("glEnableVertexAttribArray 2");
    gl.glVertexAttribPointer(2, 4, gl.GL_UNSIGNED_BYTE, gl.GL_TRUE, stride, @ptrFromInt(16));
    checkGlError("glVertexAttribPointer 2");
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
        \\out vec2 vUV;
        \\out vec4 vColor;
        \\
        \\void main() {
        \\    vUV = in_uv;
        \\    vColor = in_color;
        \\    gl_Position = u_projection * vec4(in_pos.xy, 0, 1);
        \\}
    ;

    const fs_src =
        \\#version 330 core
        \\in vec2 vUV;
        \\in vec4 vColor;
        \\
        \\uniform sampler2D uTexture;
        \\
        \\layout (location = 0) out vec4 out_color;
        \\
        \\void main() {
        \\    // Check if this is non-textured geometry (default UV is 1.0, 0.0)
        \\    if (vUV.x >= 0.99 && vUV.y <= 0.01) {
        \\        // Solid color rendering (for rectangles, shapes, etc.)
        \\        out_color = vColor;
        \\    } else {
        \\        vec4 texColor = texture(uTexture, vUV.st);
        \\        // If vertex color is white (all channels == 1.0), it's a full-color image
        \\        // Otherwise, it's text (single channel) or tinted image
        \\        if (vColor.r >= 0.99 && vColor.g >= 0.99 && vColor.b >= 0.99) {
        \\            // Full-color image rendering (use RGBA from texture)
        \\            out_color = texColor * vColor;
        \\        } else {
        \\            // Text rendering (use only red channel for alpha)
        \\            out_color = vec4(vColor.rgb, vColor.a * texColor.r);
        \\        }
        \\    }
        \\}
    ;

    const vs_ptrs = [_][*c]const u8{
        @ptrCast(vs_src),
    };

    const fs_ptrs = [_][*c]const u8{
        @ptrCast(fs_src),
    };

    const vs = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    checkGlError("glCreateShader VS");
    const fs = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    checkGlError("glCreateShader FS");

    gl.glShaderSource(vs, 1, &vs_ptrs, null);
    checkGlError("glShaderSource VS");
    gl.glCompileShader(vs);
    checkGlError("glCompileShader VS");

    var success: i32 = 0;
    gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var log: [1024]u8 = undefined;
        gl.glGetShaderInfoLog(vs, 1024, null, &log);
        std.debug.print("Vertex shader compilation failed:\n{s}\n", .{log});
    }

    gl.glShaderSource(fs, 1, &fs_ptrs, null);
    checkGlError("glShaderSource FS");
    gl.glCompileShader(fs);
    checkGlError("glCompileShader FS");

    gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var log: [1024]u8 = undefined;
        gl.glGetShaderInfoLog(fs, 1024, null, &log);
        std.debug.print("Fragment shader compilation failed:\n{s}\n", .{log});
    }

    const prog = gl.glCreateProgram();
    checkGlError("glCreateProgram");
    gl.glAttachShader(prog, vs);
    checkGlError("glAttachShader VS");
    gl.glAttachShader(prog, fs);
    checkGlError("glAttachShader FS");
    gl.glLinkProgram(prog);
    checkGlError("glLinkProgram");

    gl.glGetProgramiv(prog, gl.GL_LINK_STATUS, &success);
    if (success == 0) {
        var log: [1024]u8 = undefined;
        gl.glGetProgramInfoLog(prog, 1024, null, &log);
        std.debug.print("Shader program linking failed:\n{s}\n", .{log});
    }

    gl.glDeleteShader(vs);
    checkGlError("glDeleteShader VS");
    gl.glDeleteShader(fs);
    checkGlError("glDeleteShader FS");

    return prog;
}

pub fn checkGlError(location: []const u8) void {
    var e = gl.glGetError();
    while (e != gl.GL_NO_ERROR) {
        const error_str = switch (e) {
            gl.GL_INVALID_ENUM => "GL_INVALID_ENUM",
            gl.GL_INVALID_VALUE => "GL_INVALID_VALUE",
            gl.GL_INVALID_OPERATION => "GL_INVALID_OPERATION",
            gl.GL_STACK_OVERFLOW => "GL_STACK_OVERFLOW",
            gl.GL_STACK_UNDERFLOW => "GL_STACK_UNDERFLOW",
            gl.GL_OUT_OF_MEMORY => "GL_OUT_OF_MEMORY",
            gl.GL_INVALID_FRAMEBUFFER_OPERATION => "GL_INVALID_FRAMEFRAMEBUFFER_OPERATION",
            else => "UNKNOWN_GL_ERROR",
        };
        std.debug.print("OpenGL Error at {s}: {s}\n", .{ location, error_str });
        e = gl.glGetError();
    }
}

// orthographic projection - column-major order for OpenGL
fn ortho(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) [16]f32 {
    const rl = r - l;
    const tb = t - b;
    const fn_ = f - n;

    return .{
        // Column 0
        2.0 / rl,
        0.0,
        0.0,
        0.0,
        // Column 1
        0.0,
        2.0 / tb,
        0.0,
        0.0,
        // Column 2
        0.0,
        0.0,
        -2.0 / fn_,
        0.0,
        // Column 3
        -(r + l) / rl,
        -(t + b) / tb,
        -(f + n) / fn_,
        1.0,
    };
}
