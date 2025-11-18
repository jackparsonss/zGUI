const std = @import("std");
const c = @import("../c.zig");
const stb = c.trueType;
const gl = c.glad;

pub const TextMetrics = struct {
    width: f32,
    height: f32,
};

pub const Glyph = struct {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
    x_off: f32,
    y_off: f32,
    x_advance: f32,
    uv0: [2]f32,
    uv1: [2]f32,
};

pub const LoadError = error{
    InvalidFont,
    PackFailed,
};

pub const Font = struct {
    tex_width: i32,
    tex_height: i32,
    texture: u32,
    scale: f32,
    ascent: f32,
    descent: f32,
    line_gap: f32,
    glyphs: [256]Glyph,

    pub fn load(allocator: std.mem.Allocator, path: []const u8, pixel_height: f32) !Font {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(allocator, 4 * 1024 * 1024);

        var info: stb.stbtt_fontinfo = undefined;
        if (stb.stbtt_InitFont(&info, data.ptr, 0) == 0) {
            return LoadError.InvalidFont;
        }

        var ascent: c_int = 0;
        var descent: c_int = 0;
        var line_gap: c_int = 0;
        stb.stbtt_GetFontVMetrics(&info, &ascent, &descent, &line_gap);

        const scale = stb.stbtt_ScaleForPixelHeight(&info, pixel_height);
        const tex_width = 512;
        const tex_height = 512;

        var bitmap = try allocator.alloc(u8, tex_width * tex_height);
        @memset(bitmap[0..], 0);

        var packer: stb.stbtt_pack_context = undefined;
        if (stb.stbtt_PackBegin(&packer, bitmap.ptr, tex_width, tex_height, 0, 1, null) == 0) {
            return LoadError.PackFailed;
        }

        var range: stb.stbtt_pack_range = .{
            .font_size = pixel_height,
            .first_unicode_codepoint_in_range = 0,
            .num_chars = 256,
            .chardata_for_range = undefined,
        };

        const cd = try allocator.alloc(stb.stbtt_packedchar, 256);
        range.chardata_for_range = cd.ptr;

        if (stb.stbtt_PackFontRanges(&packer, data.ptr, 0, &range, 1) == 0) {
            return LoadError.PackFailed;
        }

        stb.stbtt_PackEnd(&packer);

        var tex: u32 = 0;
        gl.glGenTextures(1, &tex);
        gl.glBindTexture(gl.GL_TEXTURE_2D, tex);

        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);

        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            gl.GL_RED,
            tex_width,
            tex_height,
            0,
            gl.GL_RED,
            gl.GL_UNSIGNED_BYTE,
            bitmap.ptr,
        );

        var glyphs: [256]Glyph = undefined;
        for (0..256) |i| {
            const char = cd[i];
            glyphs[i] = Glyph{
                .x0 = char.x0,
                .y0 = char.y0,
                .x1 = char.x1,
                .y1 = char.y1,
                .x_off = char.xoff,
                .y_off = char.yoff,
                .x_advance = char.xadvance,
                .uv0 = .{ @as(f32, @floatFromInt(char.x0)) / tex_width, @as(f32, @floatFromInt(char.y0)) / tex_height },
                .uv1 = .{ @as(f32, @floatFromInt(char.x1)) / tex_width, @as(f32, @floatFromInt(char.y1)) / tex_height },
            };
        }

        return Font{
            .tex_width = tex_width,
            .tex_height = tex_height,
            .texture = tex,
            .scale = scale,
            .ascent = @as(f32, @floatFromInt(ascent)) * scale,
            .descent = @as(f32, @floatFromInt(descent)) * scale,
            .line_gap = @as(f32, @floatFromInt(line_gap)) * scale,
            .glyphs = glyphs,
        };
    }

    pub fn measure(self: *const Font, text: []const u8) TextMetrics {
        var width: f32 = 0.0;

        for (text) |char| {
            const idx: usize = @intCast(char);
            const g = self.glyphs[idx];
            width += g.x_advance * self.scale;
        }

        const height = (self.ascent - self.descent + self.line_gap) * self.scale;
        return TextMetrics{
            .width = width,
            .height = height,
        };
    }
};
