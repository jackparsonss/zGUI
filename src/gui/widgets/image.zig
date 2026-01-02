const std = @import("std");
const c = @import("../c.zig");
const stb_image = c.image;
const GuiContext = @import("../context.zig").GuiContext;
const shapes = @import("../shapes.zig");
const Renderer = @import("../renderer.zig").Renderer;
const TextureHandle = @import("../renderer.zig").TextureHandle;
const TextureFormat = @import("../renderer.zig").TextureFormat;

pub const LoadError = error{
    InvalidImage,
    FileNotFound,
};

pub const Image = struct {
    texture: TextureHandle,
    width: i32,
    height: i32,
    channels: i32,

    pub fn load(allocator: std.mem.Allocator, renderer: *Renderer, path: []const u8) !Image {
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        var width: c_int = 0;
        var height: c_int = 0;
        var channels: c_int = 0;

        const data = stb_image.stbi_load(path_z.ptr, &width, &height, &channels, 4);
        if (data == null) {
            return LoadError.InvalidImage;
        }
        defer stb_image.stbi_image_free(data);

        // Create texture using the renderer (RGBA format for images)
        const tex = renderer.createTexture(width, height, .rgba8, data);

        return Image{
            .texture = tex,
            .width = width,
            .height = height,
            .channels = 4,
        };
    }

    pub fn deinit(self: *Image, renderer: *Renderer) void {
        renderer.deleteTexture(self.texture);
    }
};

pub const Options = struct {
    /// Width to render the image (if null, uses image's natural width)
    width: ?f32 = null,
    /// Height to render the image (if null, uses image's natural height)
    height: ?f32 = null,
    /// Color tint to apply to the image (default: white = no tint)
    tint: shapes.Color = 0xFFFFFFFF,
};

pub fn image(ctx: *GuiContext, img: *const Image, opts: Options) !void {
    const width = opts.width orelse @as(f32, @floatFromInt(img.width));
    const height = opts.height orelse @as(f32, @floatFromInt(img.height));

    const layout = ctx.getCurrentLayout();
    const rect = layout.allocateSpace(ctx, width, height);

    try ctx.draw_list.setTexture(img.texture);
    try ctx.draw_list.addRectUV(
        rect,
        .{ 0.0, 0.0 }, // UV min (top-left)
        .{ 1.0, 1.0 }, // UV max (bottom-right)
        opts.tint,
    );
}

// Internal helper for widgets that need to position images manually (like checkbox)
pub fn imageAt(ctx: *GuiContext, x: f32, y: f32, img: *const Image, opts: Options) !void {
    const width = opts.width orelse @as(f32, @floatFromInt(img.width));
    const height = opts.height orelse @as(f32, @floatFromInt(img.height));

    const rect = shapes.Rect{
        .x = x,
        .y = y,
        .w = width,
        .h = height,
    };

    try ctx.draw_list.setTexture(img.texture);
    try ctx.draw_list.addRectUV(
        rect,
        .{ 0.0, 0.0 }, // UV min (top-left)
        .{ 1.0, 1.0 }, // UV max (bottom-right)
        opts.tint,
    );
}
