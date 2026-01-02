const std = @import("std");
const shapes = @import("shapes.zig");
const Font = @import("text/font.zig").Font;
const TextureHandle = @import("renderer.zig").TextureHandle;

pub const DrawCmd = struct {
    texture: TextureHandle,
    elem_count: u32,
    index_offset: u32,
};

pub const DrawList = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(shapes.Vertex),
    indices: std.ArrayList(u32),
    commands: std.ArrayList(DrawCmd),
    current_texture: TextureHandle,

    pub fn init(allocator: std.mem.Allocator) DrawList {
        return DrawList{
            .allocator = allocator,
            .vertices = .empty,
            .indices = .empty,
            .commands = .empty,
            .current_texture = 0,
        };
    }

    pub fn clear(self: *DrawList) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.commands.clearRetainingCapacity();
        self.current_texture = 0;
    }

    pub fn setTexture(self: *DrawList, texture: TextureHandle) !void {
        if (texture != self.current_texture) {
            self.current_texture = texture;

            // Start a new draw command for this texture
            if (self.commands.items.len > 0) {
                // Close the previous command
                const prev_cmd = &self.commands.items[self.commands.items.len - 1];
                const current_index: u32 = @intCast(self.indices.items.len);
                prev_cmd.elem_count = current_index - prev_cmd.index_offset;
            }
            // Add new command
            try self.commands.append(self.allocator, DrawCmd{
                .texture = texture,
                .elem_count = 0,
                .index_offset = @intCast(self.indices.items.len),
            });
        }
    }

    fn ensureDrawCmd(self: *DrawList) !void {
        if (self.commands.items.len == 0) {
            try self.commands.append(self.allocator, DrawCmd{
                .texture = self.current_texture,
                .elem_count = 0,
                .index_offset = 0,
            });
        }
    }

    fn updateCurrentCmd(self: *DrawList) void {
        if (self.commands.items.len > 0) {
            const cmd = &self.commands.items[self.commands.items.len - 1];
            const current_index: u32 = @intCast(self.indices.items.len);
            cmd.elem_count = current_index - cmd.index_offset;
        }
    }

    pub fn addVertex(self: *DrawList, v: shapes.Vertex) !void {
        try self.ensureDrawCmd();
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.vertices.append(self.allocator, v);
        try self.indices.append(self.allocator, idx);
        self.updateCurrentCmd();
    }

    pub fn addTriangle(self: *DrawList, v1: shapes.Vertex, v2: shapes.Vertex, v3: shapes.Vertex) !void {
        try self.ensureDrawCmd();
        try self.addVertex(v1);
        try self.addVertex(v2);
        try self.addVertex(v3);
    }

    pub fn addRect(self: *DrawList, rect: shapes.Rect, color: shapes.Color) !void {
        try self.ensureDrawCmd();
        const rgba = shapes.colorToRGBA(color);
        const v1 = shapes.Vertex{ .pos = .{ rect.x, rect.y }, .color = rgba };
        const v2 = shapes.Vertex{ .pos = .{ rect.x + rect.w, rect.y }, .color = rgba };
        const v3 = shapes.Vertex{ .pos = .{ rect.x + rect.w, rect.y + rect.h }, .color = rgba };
        const v4 = shapes.Vertex{ .pos = .{ rect.x, rect.y + rect.h }, .color = rgba };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &[_]shapes.Vertex{ v1, v2, v3, v4 });
        try self.indices.appendSlice(self.allocator, &[_]u32{
            base, base + 1, base + 2,
            base, base + 2, base + 3,
        });
        self.updateCurrentCmd();
    }

    pub fn addRoundedRect(self: *DrawList, rect: shapes.Rect, radius: f32, color: shapes.Color) !void {
        try self.ensureDrawCmd();

        const segments_per_corner = 8;
        const pi = std.math.pi;

        // Clamp radius to not exceed half of the smallest dimension
        const max_radius = @min(rect.w, rect.h) * 0.5;
        const r = @min(radius, max_radius);

        // Corner centers and their start angles (going clockwise from top-left)
        const corners = [4][2]f32{
            .{ rect.x + r, rect.y + r }, // Top-left
            .{ rect.x + rect.w - r, rect.y + r }, // Top-right
            .{ rect.x + rect.w - r, rect.y + rect.h - r }, // Bottom-right
            .{ rect.x + r, rect.y + rect.h - r }, // Bottom-left
        };

        const start_angles = [4]f32{
            pi, // Top-left: start at π (pointing left)
            1.5 * pi, // Top-right: start at 3π/2 (pointing up)
            0.0, // Bottom-right: start at 0 (pointing right)
            0.5 * pi, // Bottom-left: start at π/2 (pointing down)
        };

        const base: u32 = @intCast(self.vertices.items.len);
        const rgba = shapes.colorToRGBA(color);

        // Center vertex for triangle fan
        const center_x = rect.x + rect.w * 0.5;
        const center_y = rect.y + rect.h * 0.5;
        try self.vertices.append(self.allocator, shapes.Vertex{
            .pos = .{ center_x, center_y },
            .color = rgba,
        });

        // Generate vertices for each corner arc
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var seg: usize = 0;
            while (seg <= segments_per_corner) : (seg += 1) {
                const t = @as(f32, @floatFromInt(seg)) / @as(f32, @floatFromInt(segments_per_corner));
                const angle = start_angles[i] + t * pi * 0.5;
                const x = corners[i][0] + @cos(angle) * r;
                const y = corners[i][1] + @sin(angle) * r;

                try self.vertices.append(self.allocator, shapes.Vertex{
                    .pos = .{ x, y },
                    .color = rgba,
                });
            }
        }

        // Generate indices for triangle fan
        const vertex_count = 1 + 4 * (segments_per_corner + 1);
        var idx: u32 = 1;
        while (idx < vertex_count - 1) : (idx += 1) {
            try self.indices.appendSlice(self.allocator, &[_]u32{
                base, // Center
                base + idx, // Current vertex
                base + idx + 1, // Next vertex
            });
        }

        // Close the loop
        try self.indices.appendSlice(self.allocator, &[_]u32{
            base,
            base + vertex_count - 1,
            base + 1,
        });

        self.updateCurrentCmd();
    }

    pub fn addRoundedRectOutline(self: *DrawList, rect: shapes.Rect, radius: f32, thickness: f32, color: shapes.Color) !void {
        try self.ensureDrawCmd();

        const segments_per_corner = 8;
        const pi = std.math.pi;

        // Clamp radius to not exceed half of the smallest dimension
        const max_radius = @min(rect.w, rect.h) * 0.5;
        const r = @min(radius, max_radius);

        // Clamp thickness to not exceed radius
        const t = @min(thickness, r);
        const inner_radius = r - t;

        // Corner centers and their start angles (going clockwise from top-left)
        const corners = [4][2]f32{
            .{ rect.x + r, rect.y + r }, // Top-left
            .{ rect.x + rect.w - r, rect.y + r }, // Top-right
            .{ rect.x + rect.w - r, rect.y + rect.h - r }, // Bottom-right
            .{ rect.x + r, rect.y + rect.h - r }, // Bottom-left
        };

        const start_angles = [4]f32{
            pi, // Top-left: start at π (pointing left)
            1.5 * pi, // Top-right: start at 3π/2 (pointing up)
            0.0, // Bottom-right: start at 0 (pointing right)
            0.5 * pi, // Bottom-left: start at π/2 (pointing down)
        };

        const base: u32 = @intCast(self.vertices.items.len);
        const rgba = shapes.colorToRGBA(color);

        // Generate outer and inner vertices for each corner arc
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var seg: usize = 0;
            while (seg <= segments_per_corner) : (seg += 1) {
                const angle_t = @as(f32, @floatFromInt(seg)) / @as(f32, @floatFromInt(segments_per_corner));
                const angle = start_angles[i] + angle_t * pi * 0.5;

                // Outer vertex
                const outer_x = corners[i][0] + @cos(angle) * r;
                const outer_y = corners[i][1] + @sin(angle) * r;
                try self.vertices.append(self.allocator, shapes.Vertex{
                    .pos = .{ outer_x, outer_y },
                    .color = rgba,
                });

                // Inner vertex
                const inner_x = corners[i][0] + @cos(angle) * inner_radius;
                const inner_y = corners[i][1] + @sin(angle) * inner_radius;
                try self.vertices.append(self.allocator, shapes.Vertex{
                    .pos = .{ inner_x, inner_y },
                    .color = rgba,
                });
            }
        }

        // Generate indices to form triangles between outer and inner vertices
        const vertices_per_corner = segments_per_corner + 1;
        const total_vertex_pairs = 4 * vertices_per_corner;

        var pair: u32 = 0;
        while (pair < total_vertex_pairs) : (pair += 1) {
            const next_pair = (pair + 1) % total_vertex_pairs;

            const outer_curr = base + pair * 2;
            const inner_curr = base + pair * 2 + 1;
            const outer_next = base + next_pair * 2;
            const inner_next = base + next_pair * 2 + 1;

            // Two triangles forming a quad between current and next pair
            try self.indices.appendSlice(self.allocator, &[_]u32{
                outer_curr, inner_curr, outer_next,
            });
            try self.indices.appendSlice(self.allocator, &[_]u32{
                inner_curr, inner_next, outer_next,
            });
        }

        self.updateCurrentCmd();
    }

    pub fn addRectUV(
        self: *DrawList,
        rect: shapes.Rect,
        uv_min: [2]f32,
        uv_max: [2]f32,
        color: shapes.Color,
    ) !void {
        try self.ensureDrawCmd();
        const x1 = rect.x;
        const y1 = rect.y;
        const x2 = rect.x + rect.w;
        const y2 = rect.y + rect.h;

        const uv1 = uv_min[0];
        const v1 = uv_min[1];
        const uv2 = uv_max[0];
        const v2 = uv_max[1];

        const rgba = shapes.colorToRGBA(color);
        const vtx = [_]shapes.Vertex{
            .{ .pos = .{ x1, y1 }, .uv = .{ uv1, v1 }, .color = rgba },
            .{ .pos = .{ x2, y1 }, .uv = .{ uv2, v1 }, .color = rgba },
            .{ .pos = .{ x2, y2 }, .uv = .{ uv2, v2 }, .color = rgba },
            .{ .pos = .{ x1, y2 }, .uv = .{ uv1, v2 }, .color = rgba },
        };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &vtx);

        try self.indices.appendSlice(self.allocator, &[_]u32{
            base, base + 1, base + 2,
            base, base + 2, base + 3,
        });
        self.updateCurrentCmd();
    }

    /// Add a textured rectangle with rotation around its center
    /// angle: rotation in radians (positive = counter-clockwise)
    pub fn addRectUVRotated(
        self: *DrawList,
        rect: shapes.Rect,
        uv_min: [2]f32,
        uv_max: [2]f32,
        color: shapes.Color,
        angle: f32,
    ) !void {
        try self.ensureDrawCmd();

        // Calculate center point
        const cx = rect.x + rect.w * 0.5;
        const cy = rect.y + rect.h * 0.5;

        // Half dimensions for corners relative to center
        const half_w = rect.w * 0.5;
        const half_h = rect.h * 0.5;

        // Precompute rotation
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);

        // Apply 2D rotation matrix to each corner
        // [x'] = [cos(θ)  -sin(θ)] [x] + [cx]
        // [y']   [sin(θ)   cos(θ)] [y]   [cy]

        // Top-left: (-half_w, -half_h)
        const tl_x = cx + (-half_w * cos_a - (-half_h) * sin_a);
        const tl_y = cy + (-half_w * sin_a + (-half_h) * cos_a);

        // Top-right: (half_w, -half_h)
        const tr_x = cx + (half_w * cos_a - (-half_h) * sin_a);
        const tr_y = cy + (half_w * sin_a + (-half_h) * cos_a);

        // Bottom-right: (half_w, half_h)
        const br_x = cx + (half_w * cos_a - half_h * sin_a);
        const br_y = cy + (half_w * sin_a + half_h * cos_a);

        // Bottom-left: (-half_w, half_h)
        const bl_x = cx + (-half_w * cos_a - half_h * sin_a);
        const bl_y = cy + (-half_w * sin_a + half_h * cos_a);

        const rgba = shapes.colorToRGBA(color);
        const uv1 = uv_min[0];
        const v1 = uv_min[1];
        const uv2 = uv_max[0];
        const v2 = uv_max[1];

        const vtx = [_]shapes.Vertex{
            .{ .pos = .{ tl_x, tl_y }, .uv = .{ uv1, v1 }, .color = rgba },
            .{ .pos = .{ tr_x, tr_y }, .uv = .{ uv2, v1 }, .color = rgba },
            .{ .pos = .{ br_x, br_y }, .uv = .{ uv2, v2 }, .color = rgba },
            .{ .pos = .{ bl_x, bl_y }, .uv = .{ uv1, v2 }, .color = rgba },
        };

        const base: u32 = @intCast(self.vertices.items.len);
        try self.vertices.appendSlice(self.allocator, &vtx);

        try self.indices.appendSlice(self.allocator, &[_]u32{
            base, base + 1, base + 2,
            base, base + 2, base + 3,
        });
        self.updateCurrentCmd();
    }

    pub fn addText(self: *DrawList, font: *const Font, x: f32, y: f32, text: []const u8, color: shapes.Color) !void {
        var cursor_x = x;
        const cursor_y = y + font.ascent;

        for (text) |c| {
            const glyph_index: usize = @intCast(c);
            const g = font.glyphs[glyph_index];

            const gx0 = cursor_x + g.x_off;
            const gy0 = cursor_y + g.y_off;
            const gx1 = gx0 + (@as(f32, @floatFromInt(g.x1 - g.x0)));
            const gy1 = gy0 + (@as(f32, @floatFromInt(g.y1 - g.y0)));

            try self.addRectUV(.{ .x = gx0, .y = gy0, .w = gx1 - gx0, .h = gy1 - gy0 }, g.uv0, g.uv1, color);

            cursor_x += g.x_advance;
        }
    }

    pub fn deinit(self: *DrawList) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.commands.deinit(self.allocator);
    }
};
