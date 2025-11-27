const builtin = @import("builtin");
const std = @import("std");

const GLRenderer = @import("renderers/opengl.zig").GLRenderer;
const FontCache = @import("text/font_cache.zig").FontCache;
const TextMetrics = @import("text/font.zig").TextMetrics;
const DrawList = @import("draw_list.zig").DrawList;
const Image = @import("widgets/image.zig").Image;
const Layout = @import("layout.zig").Layout;
const Input = @import("input.zig").Input;
const shapes = @import("shapes.zig");
const c = @import("c.zig");
const Window = c.Window;
const glfw = c.glfw;

pub const ActiveInputState = struct {
    cursor_pos: usize,
    scroll_offset: f32,
    selection_start: ?usize,
    cursor_blink_time: f64,
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

pub const ResizeBorder = enum {
    left,
    right,
    top,
    bottom,
};

pub const ResizeState = struct {
    dragging: bool,
    panel_id: u64,
    border: ResizeBorder,
    initial_mouse_pos: f32,
    panel_rect: shapes.Rect,
    initial_x_offset: f32,
    initial_y_offset: f32,

    pub fn init() ResizeState {
        return .{
            .dragging = false,
            .panel_id = 0,
            .border = .right,
            .initial_mouse_pos = 0.0,
            .panel_rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
            .initial_x_offset = 0.0,
            .initial_y_offset = 0.0,
        };
    }
};

pub const PanelSize = struct {
    width: ?f32,
    height: ?f32,
    min_width: f32 = 0.0,
    min_height: f32 = 0.0,
    x_offset: f32 = 0.0,
    y_offset: f32 = 0.0,
};

pub const GuiContext = struct {
    draw_list: DrawList,
    input: Input,
    font_cache: FontCache,
    current_font_texture: u32,
    window: c.Window,
    checkmark_image: Image,

    // Active input widget state (only exists when an input is focused)
    active_input_id: ?u64,
    active_input_state: ?ActiveInputState,

    // Panel resize state
    resize_state: ResizeState,
    panel_sizes: std.AutoHashMap(u64, PanelSize),
    current_panel_id: ?u64, // Track which panel the current layout belongs to

    // Layout stack for managing nested layouts
    layout_stack: std.ArrayList(Layout),
    allocator: std.mem.Allocator,

    // Global layout position tracking for automatic positioning
    next_layout_x: f32,
    next_layout_y: f32,
    layout_row_max_height: f32, // Track max height in current row for wrapping
    window_width: f32, // Current window width
    window_height: f32, // Current window height

    // Widget ID counter (reset each frame for stable IDs)
    id_counter: u64,

    // Track if we're currently resizing to skip expensive UI rebuilding
    is_resizing: bool,
    last_resize_time: f64,

    // Cursor management
    arrow_cursor: ?*glfw.GLFWcursor,
    hresize_cursor: ?*glfw.GLFWcursor,
    vresize_cursor: ?*glfw.GLFWcursor,
    ibeam_cursor: ?*glfw.GLFWcursor,
    current_cursor: ?*glfw.GLFWcursor,

    pub fn init(allocator: std.mem.Allocator, window: c.Window) !GuiContext {
        const checkmark_image = try Image.load(allocator, "assets/checkmark.png");

        const arrow_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
        const hresize_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_HRESIZE_CURSOR);
        const vresize_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_VRESIZE_CURSOR);
        const ibeam_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_IBEAM_CURSOR);

        const ctx = GuiContext{
            .allocator = allocator,
            .draw_list = DrawList.init(allocator),
            .input = Input.init(),
            .font_cache = FontCache.init(allocator, "src/gui/text/RobotoMono-Regular.ttf"),
            .current_font_texture = 0,
            .checkmark_image = checkmark_image,

            .window = window,
            .window_width = 0.0,
            .window_height = 0.0,
            .active_input_id = null,
            .active_input_state = null,
            .resize_state = ResizeState.init(),
            .panel_sizes = std.AutoHashMap(u64, PanelSize).init(allocator),
            .current_panel_id = null,
            .layout_stack = .empty,
            .next_layout_x = 0.0,
            .next_layout_y = 0.0,
            .layout_row_max_height = 0.0,
            .id_counter = 0,
            .is_resizing = false,
            .last_resize_time = 0.0,

            // cursors
            .arrow_cursor = arrow_cursor,
            .hresize_cursor = hresize_cursor,
            .vresize_cursor = vresize_cursor,
            .ibeam_cursor = ibeam_cursor,
            .current_cursor = arrow_cursor,
        };
        return ctx;
    }

    pub fn newFrame(self: *GuiContext) void {
        self.input.beginFrame();
        self.draw_list.clear();
        self.layout_stack.clearRetainingCapacity();
        self.current_panel_id = null;
        self.next_layout_x = 0.0;
        self.next_layout_y = 0.0;
        self.layout_row_max_height = 0.0;
        self.id_counter = 0;

        const current_time = glfw.glfwGetTime();
        if (self.is_resizing and (current_time - self.last_resize_time) > 0.05) {
            self.is_resizing = false;
        }

        self.setCursor(self.arrow_cursor);
    }

    pub fn updateInput(self: *GuiContext, window: Window) void {
        self.input.update(window);
    }

    pub fn handleMouseButton(self: *GuiContext, button: c_int, action: c_int) void {
        if (action != glfw.GLFW_PRESS) {
            return;
        }

        if (button == glfw.GLFW_MOUSE_BUTTON_LEFT) {
            self.input.registerMouseClick();
        } else if (button == glfw.GLFW_MOUSE_BUTTON_RIGHT) {
            self.input.registerRightClick();
        } else if (button == glfw.GLFW_MOUSE_BUTTON_MIDDLE) {
            self.input.registerMiddleClick();
        }
    }

    pub fn handleChar(self: *GuiContext, codepoint: c_uint) void {
        self.input.registerChar(codepoint);
    }

    pub fn handleKey(self: *GuiContext, key: c_int, action: c_int) void {
        self.input.registerKey(key, action);
    }

    pub fn handleModifiers(self: *GuiContext, mods: c_int) void {
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
        self.panel_sizes.deinit();

        if (self.arrow_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.hresize_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.vresize_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.ibeam_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
    }

    pub fn getCurrentLayout(self: *GuiContext) ?*Layout {
        if (self.layout_stack.items.len == 0) return null;
        return &self.layout_stack.items[self.layout_stack.items.len - 1];
    }

    pub fn assertCurrentLayout(self: *GuiContext) *Layout {
        if (self.layout_stack.items.len == 0) {
            @panic("image widget must be used inside a layout");
        }
        return &self.layout_stack.items[self.layout_stack.items.len - 1];
    }

    pub fn getNextLayoutPos(self: *GuiContext) struct { x: f32, y: f32 } {
        return .{ .x = self.next_layout_x, .y = self.next_layout_y };
    }

    pub fn setWindowSize(self: *GuiContext, width: f32, height: f32) void {
        self.window_width = width;
        self.window_height = height;
        self.is_resizing = true;
        self.last_resize_time = glfw.glfwGetTime();
    }

    pub fn updateLayoutPos(self: *GuiContext, bounds: shapes.Rect) void {
        self.next_layout_x = 0.0;
        self.next_layout_y = bounds.y + bounds.h;
        self.layout_row_max_height = 0.0;
    }

    pub fn setCursor(self: *GuiContext, cursor: ?*glfw.GLFWcursor) void {
        if (self.current_cursor != cursor) {
            glfw.glfwSetCursor(self.window, cursor);
            self.current_cursor = cursor;
        }
    }
};
