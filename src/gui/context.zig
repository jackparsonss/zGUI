const builtin = @import("builtin");
const std = @import("std");

const FontCache = @import("text/font_cache.zig").FontCache;
const TextMetrics = @import("text/font.zig").TextMetrics;
const DrawList = @import("draw_list.zig").DrawList;
const GLRenderer = @import("renderers/opengl.zig").GLRenderer;
const shapes = @import("shapes.zig");
const Input = @import("input.zig").Input;
const imageWidget = @import("widgets/image.zig");
const Layout = @import("layout.zig").Layout;
const c = @import("c.zig");
const Window = c.Window;

// Internal state for the active text input widget
pub const ActiveInputState = struct {
    cursor_pos: usize,
    scroll_offset: f32,
    selection_start: ?usize,
    cursor_blink_time: f64,
    // For inputNumber: preserve the text buffer while editing
    number_buffer: ?[32]u8,
    number_buffer_len: usize,

    pub fn init() ActiveInputState {
        return .{
            .cursor_pos = 0,
            .scroll_offset = 0.0,
            .selection_start = null,
            .cursor_blink_time = 0.0,
            .number_buffer = null,
            .number_buffer_len = 0,
        };
    }
};

pub const GuiContext = struct {
    draw_list: DrawList,
    input: Input,
    font_cache: FontCache,
    current_font_texture: u32,
    window: c.Window,
    checkmark_image: imageWidget.Image,

    // Active input widget state (only exists when an input is focused)
    active_input_id: ?u64,
    active_input_state: ?ActiveInputState,

    // Layout stack for managing nested layouts
    layout_stack: std.ArrayList(Layout),
    allocator: std.mem.Allocator,

    // Global layout position tracking for automatic positioning
    next_layout_x: f32,
    next_layout_y: f32,
    layout_row_max_height: f32, // Track max height in current row for wrapping
    window_width: f32, // Current window width
    window_height: f32, // Current window height

    pub fn init(allocator: std.mem.Allocator, window: c.Window) !GuiContext {
        const checkmark_image = try imageWidget.Image.load(allocator, "assets/checkmark.png");

        const ctx = GuiContext{
            .draw_list = DrawList.init(allocator),
            .input = Input.init(),
            .font_cache = FontCache.init(allocator, "src/gui/text/RobotoMono-Regular.ttf"),
            .current_font_texture = 0,
            .window = window,
            .checkmark_image = checkmark_image,
            .active_input_id = null,
            .active_input_state = null,
            .layout_stack = .empty,
            .allocator = allocator,
            .next_layout_x = 0.0,
            .next_layout_y = 0.0,
            .layout_row_max_height = 0.0,
            .window_width = 0.0,
            .window_height = 0.0,
        };
        return ctx;
    }

    pub fn newFrame(self: *GuiContext) void {
        self.input.beginFrame();
        self.draw_list.clear();
        // Clear layout stack at the start of each frame
        self.layout_stack.clearRetainingCapacity();
        // Reset layout position tracking
        self.next_layout_x = 0.0;
        self.next_layout_y = 0.0;
        self.layout_row_max_height = 0.0;
    }

    pub fn updateInput(self: *GuiContext, window: Window) void {
        self.input.update(window);
    }

    pub fn handleMouseButton(self: *GuiContext, button: c_int, action: c_int) void {
        const glfw = c.glfw;

        if (action == glfw.GLFW_PRESS) {
            if (button == glfw.GLFW_MOUSE_BUTTON_LEFT) {
                self.input.registerMouseClick();
            } else if (button == glfw.GLFW_MOUSE_BUTTON_RIGHT) {
                self.input.registerRightClick();
            } else if (button == glfw.GLFW_MOUSE_BUTTON_MIDDLE) {
                self.input.registerMiddleClick();
            }
        }
    }

    pub fn handleChar(self: *GuiContext, codepoint: c_uint) void {
        self.input.registerChar(codepoint);
    }

    pub fn handleKey(self: *GuiContext, key: c_int, action: c_int) void {
        self.input.registerKey(key, action);
    }

    pub fn handleModifiers(self: *GuiContext, mods: c_int) void {
        const glfw = c.glfw;
        self.input.ctrl_pressed = (mods & glfw.GLFW_MOD_CONTROL) != 0;
        self.input.alt_pressed = (mods & glfw.GLFW_MOD_ALT) != 0;
        self.input.super_pressed = (mods & glfw.GLFW_MOD_SUPER) != 0;
        self.input.shift_pressed = (mods & glfw.GLFW_MOD_SHIFT) != 0;

        if (comptime builtin.target.os.tag == .macos) {
            self.input.primary_pressed = self.input.super_pressed;
        } else {
            self.input.primary_pressed = self.input.ctrl_pressed;
        }
    }

    pub fn handleScroll(self: *GuiContext, xoffset: f64, yoffset: f64) void {
        self.input.registerScroll(xoffset, yoffset);
    }

    pub fn render(self: *GuiContext, renderer: *GLRenderer, width: i32, height: i32) void {
        renderer.render(self, width, height);
    }

    pub fn measureText(self: *GuiContext, text: []const u8, font_size: f32) !TextMetrics {
        const font = try self.font_cache.getFont(font_size);
        return font.measure(text);
    }

    pub fn addText(self: *GuiContext, x: f32, y: f32, text: []const u8, font_size: f32, color: shapes.Color) !void {
        const font = try self.font_cache.getFont(font_size);
        self.current_font_texture = font.texture;
        try self.draw_list.setTexture(font.texture);
        try self.draw_list.addText(font, x, y, text, color);
    }

    pub fn deinit(self: *GuiContext) void {
        self.draw_list.deinit();
        self.font_cache.deinit();
        self.checkmark_image.deinit();
        self.layout_stack.deinit(self.allocator);
    }

    pub fn getCurrentLayout(self: *GuiContext) ?*Layout {
        if (self.layout_stack.items.len == 0) return null;
        return &self.layout_stack.items[self.layout_stack.items.len - 1];
    }

    pub fn getNextLayoutPos(self: *GuiContext) struct { x: f32, y: f32 } {
        return .{ .x = self.next_layout_x, .y = self.next_layout_y };
    }

    pub fn setWindowSize(self: *GuiContext, width: f32, height: f32) void {
        self.window_width = width;
        self.window_height = height;
    }

    pub fn updateLayoutPos(self: *GuiContext, bounds: shapes.Rect) void {
        self.next_layout_x = 0.0;
        self.next_layout_y = bounds.y + bounds.h;
        self.layout_row_max_height = 0.0;
    }
};
