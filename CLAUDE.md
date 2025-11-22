# CLAUDE.md - zGUI Codebase Guide for AI Assistants

## Project Overview

**zGUI** is an immediate-mode GUI library written in Zig, featuring OpenGL-based rendering with text support via stb_truetype. The project is in active development, currently supporting interactive buttons with click detection, multi-size text rendering, and rounded corners.

### Key Facts

- **Language**: Zig (minimum version 0.15.2)
- **Build System**: Zig build system (build.zig)
- **Graphics**: OpenGL 3.3 Core Profile
- **Dependencies**: GLFW (windowing), GLAD (OpenGL loader), stb_truetype (font rendering)
- **Current State**: Phase 1 (v0.2) - Interactive widgets with full keyboard/mouse input (~80% complete)
- **Roadmap**: See [roadmap.md](roadmap.md) for the full development plan

## Repository Structure

```
zGUI/
├── src/
│   ├── main.zig                    # Application entry point
│   └── gui/
│       ├── c.zig                   # C library bindings (GLFW, GLAD, stb_truetype)
│       ├── context.zig             # GuiContext - main GUI state container
│       ├── draw_list.zig           # DrawList - vertex/index buffer management
│       ├── input.zig               # Input handling (mouse clicks, hover detection)
│       ├── shapes.zig              # Shape primitives (Vertex, Rect, Color)
│       ├── renderers/
│       │   └── opengl.zig          # OpenGL renderer implementation
│       ├── widgets/
│       │   ├── button.zig          # Button widget with click detection
│       │   ├── checkbox.zig        # Checkbox widget with toggle
│       │   └── input.zig           # Text input widget with full editing support
│       └── text/
│           ├── font.zig            # Font loading and text measurement
│           ├── font_cache.zig      # Multi-size font caching system
│           └── RobotoMono-Regular.ttf  # Default font
├── external/
│   └── font/
│       ├── stb_truetype.c          # stb_truetype implementation
│       └── stb_truetype.h          # stb_truetype header
├── build.zig                       # Build configuration
├── build.zig.zon                   # Dependency management
├── roadmap.md                      # Development roadmap (v0.1 → v1.0+)
├── CLAUDE.md                       # This file
└── README.md

```

## Architecture

### Core Components

#### 1. **GuiContext** (`src/gui/context.zig`)

The central state manager for the GUI system.

```zig
pub const GuiContext = struct {
    draw_list: DrawList,        // Command buffer for rendering
    input: Input,               // Input state (mouse, keyboard, modifiers)
    font_cache: FontCache,      // Multi-size font cache
    current_font_texture: u32,  // Currently active font texture
    window: c.Window,           // GLFW window handle for clipboard access
}
```

**Key responsibilities:**

- Manages the draw list (vertex/index buffers)
- Tracks input state via Input struct (cursor, clicks, keyboard, modifiers)
- Manages font cache for multiple font sizes
- Provides text measurement and rendering helpers (`measureText`, `addText`)
- Handles input callbacks from GLFW (mouse, keyboard, character input)
- Orchestrates rendering via the renderer

#### 2. **DrawList** (`src/gui/draw_list.zig`)

Immediate-mode command buffer that accumulates geometry for rendering.

**Key methods:**

- `addVertex()` - Add a single vertex
- `addTriangle()` - Add a triangle (3 vertices)
- `addRect()` - Add a filled rectangle (2 triangles)
- `addRoundedRect()` - Add a filled rounded rectangle
- `addRoundedRectOutline()` - Add a rounded rectangle outline
- `addRectUV()` - Add textured rectangle with UV coordinates
- `addText()` - Add text glyphs as textured rectangles
- `setTexture()` - Switch active texture (creates new draw command)
- `clear()` - Clear buffers for next frame

**Design pattern:** Immediate-mode - buffers are cleared each frame and rebuilt. Batching by texture via draw commands.

#### 3. **GLRenderer** (`src/gui/renderers/opengl.zig`)

OpenGL 3.3 Core renderer using vertex arrays and shaders.

**Features:**

- Single shader program for all rendering
- Orthographic projection matrix
- Vertex format: position (vec2) + UV (vec2) + color (vec4 ubyte)
- Dynamic buffer updates each frame
- Blend mode enabled for alpha transparency

**Shaders:**

- Vertex shader: Transforms vertices with orthographic projection
- Fragment shader: Samples texture and multiplies with vertex color (for text)

#### 4. **Input System** (`src/gui/input.zig`)

Handles all user input events from mouse and keyboard.

**Features:**

- Mouse cursor position tracking (with DPI scaling)
- Mouse button state (left button: pressed, clicked)
- Keyboard key tracking (pressed, just pressed)
- Character input buffer for text entry
- Modifier key tracking (Ctrl, Alt, Shift, Super)
- Platform-specific primary modifier (Cmd on macOS, Ctrl on Windows/Linux)
- Click detection and hover detection helpers

**Key methods:**

- `update()` - Update cursor position and mouse state
- `beginFrame()` - Reset per-frame state (clicks, character buffer)
- `registerMouseClick()` - Record a mouse click event
- `registerChar()` - Add character to input buffer
- `registerKey()` - Track key press/release
- `isMouseInRect()` - Check if cursor is within a rectangle
- `isKeyPressed()` - Check if key is currently held
- `isKeyJustPressed()` - Check if key was just pressed this frame

**GLFW Callbacks:**

The system uses GLFW callbacks defined in `input.zig`:
- `mouseButtonCallback` - Handles mouse button events
- `charCallback` - Handles character input for typing
- `keyCallback` - Handles keyboard key events and modifiers

#### 5. **Font System** (`src/gui/text/font.zig`, `font_cache.zig`)

TrueType font rendering using stb_truetype.

**Implementation details:**

- Loads .ttf files at runtime
- Packs 256 ASCII glyphs into a 512x512 texture atlas
- Stores glyph metrics (advance, offset, bounds, UVs)
- Provides text measurement for layout

**Key methods:**

- `Font.load()` - Load font from file path at a specific size
- `measure()` - Calculate text dimensions for layout
- `FontCache.getFont()` - Get or create a font at a specific size

### Data Flow

```
GLFW Events → Callbacks (mouseButtonCallback, charCallback, keyCallback)
                                         ↓
                              GuiContext.handle*() methods
                                         ↓
                              Input.register*() methods
                                         ↓
Main Loop:
  GuiContext.newFrame() → Input.beginFrame()
                                         ↓
  GuiContext.updateInput() → Input.update()
                                         ↓
  Widget Functions → Check Input State → Add Geometry to DrawList
                                         ↓
  GuiContext.render() → GLRenderer.render()
                                         ↓
                       OpenGL → Screen
```

## Build System

### Dependencies (build.zig.zon)

1. **glfw_zig** - GLFW windowing library wrapper
   - URL: <https://github.com/tiawl/glfw.zig.git>
   - Hash: `glfw_zig-1.0.0-NrvYo77XGQA9NU8VB0GNwNWTpnn70DboOGXKPmFNJjme`

2. **zig_glad** - OpenGL function loader
   - URL: <https://github.com/jackparsonss/zig.glad.git>
   - Hash: `zig_glad-0.0.3-6OirnirhBgDz6aL0IVJ_YtvIOeyKeXklRLvT1mTH878m`

3. **stb_truetype** - Font rendering (bundled in `external/font/`)
   - C source compiled directly into the project

### Build Commands

```bash
# Build the project
zig build

# Build and run
zig build run

# Clean build cache
rm -rf .zig-cache zig-out
```

### Build Configuration Highlights

- Executable name: `zgui`
- Entry point: `src/main.zig`
- C source: `external/font/stb_truetype.c` compiled with `-O3`
- Include path: `external/font/` for stb_truetype.h

## Development Workflows

### Adding a New Widget

1. Create widget file in `src/gui/widgets/`
2. Widget signature should follow this pattern:

   ```zig
   pub fn widgetName(ctx: *GuiContext, rect: shapes.Rect, ...) !bool
   ```

3. Widget should:
   - Add geometry to `ctx.draw_list`
   - Return `true` if interacted with, `false` otherwise
   - Handle layout internally or accept positioned rect
4. Import in `main.zig` and use in the main loop

**Example pattern (button widget):**

```zig
pub fn button(ctx: *GuiContext, rect: shapes.Rect, label: []const u8, opts: ButtonOptions) !bool {
    const is_hovered = ctx.input.isMouseInRect(rect);
    const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

    // Render button background
    try ctx.draw_list.addRoundedRect(rect, opts.border_radius, opts.color);

    // Render centered text
    const metrics = try ctx.measureText(label, opts.font_size);
    const tx = rect.x + (rect.w - metrics.width) * 0.5;
    const ty = rect.y + (rect.h - opts.font_size) * 0.5;
    try ctx.addText(tx, ty, label, opts.font_size, opts.text_color);

    return is_clicked;
}
```

**Available Widgets:**

1. **Button** (`widgets/button.zig`) - Clickable button with hover detection
2. **Checkbox** (`widgets/checkbox.zig`) - Toggle checkbox with filled/outlined states
3. **Text Input** (`widgets/input.zig`) - Full-featured single-line text input with:
   - Cursor movement and blinking animation
   - Text selection with visual highlighting
   - Clipboard operations (copy/paste)
   - Word-wise navigation (Ctrl/Alt + arrows)
   - Horizontal scrolling for long text
   - Platform-aware keyboard shortcuts

### Adding a New Renderer

1. Create renderer in `src/gui/renderers/`
2. Implement a struct with these methods:
   - `init()` - Setup graphics resources
   - `render(ctx: *GuiContext, width: i32, height: i32)` - Render the draw list
3. Update `GuiContext.render()` to use the new renderer

### Input Handling

All input is handled through the Input system in `src/gui/input.zig`:

**Setting up callbacks:**

```zig
// In main.zig, register GLFW callbacks
glfw.glfwSetMouseButtonCallback(window, input.mouseButtonCallback);
glfw.glfwSetCharCallback(window, input.charCallback);
glfw.glfwSetKeyCallback(window, input.keyCallback);

// Set GuiContext as window user pointer so callbacks can access it
glfw.glfwSetWindowUserPointer(window, &gui);
```

**Using input in widgets:**

```zig
// Check mouse hover
const is_hovered = ctx.input.isMouseInRect(rect);

// Check for click this frame
const is_clicked = is_hovered and ctx.input.mouse_left_clicked;

// Check keyboard input
if (ctx.input.isKeyJustPressed(glfw.GLFW_KEY_ENTER)) {
    // Handle Enter key
}

// Access modifier keys
if (ctx.input.ctrl_pressed and ctx.input.isKeyJustPressed(glfw.GLFW_KEY_C)) {
    // Handle Ctrl+C
}

// Use platform-specific primary modifier
if (ctx.input.primary_pressed and ctx.input.isKeyJustPressed(glfw.GLFW_KEY_S)) {
    // Cmd+S on Mac, Ctrl+S on Windows/Linux
}
```

**Per-frame cycle:**

1. `ctx.newFrame()` - Resets per-frame input state
2. GLFW callbacks fire during event polling
3. `ctx.updateInput()` - Updates cursor position and mouse state
4. Widget functions read input state
5. Repeat next frame

### Error Handling

- Use Zig error unions (`!Type`) for fallible operations
- Common errors:
  - `OutOfMemory` - Allocation failures
  - `LoadError.InvalidFont` - Font loading failures
  - `LoadError.PackFailed` - Font atlas packing failures
- OpenGL errors logged via `checkGlError()` in debug builds

## Code Conventions

### Naming Conventions

- **Types**: PascalCase (`GuiContext`, `DrawList`, `GLRenderer`)
- **Functions**: camelCase (`addRect`, `updateInput`, `createShader`)
- **Constants**: SCREAMING_SNAKE_CASE for C bindings (via @cImport)
- **Variables**: snake_case (`draw_list`, `cursor_pos`, `tex_width`)

### File Organization

- One primary type per file
- File name matches primary type in snake_case
- Public API marked with `pub`
- Helper functions can be private (no `pub`)

### Import Patterns

```zig
// Standard library
const std = @import("std");

// C bindings
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;

// Internal modules
const GuiContext = @import("context.zig").GuiContext;
const shapes = @import("shapes.zig");
```

### Memory Management

- Use allocators explicitly - no hidden allocations
- `GuiContext.init(allocator)` - pass allocator at init time
- `defer deinit()` pattern for cleanup
- DrawList grows dynamically but retains capacity between frames

### Color Format

Colors are `[4]u8` - RGBA with values 0-255:

```zig
pub const Color = [4]u8;

// Examples:
.{ 255, 200, 100, 1 }   // Orange, full alpha
.{ 0, 0, 0, 1 }         // Black, full alpha
.{ 255, 255, 255, 1 }   // White, full alpha
```

Note: Alpha appears to be 0-1 range in practice (see examples), may need clarification.

### Vertex Format

```zig
pub const Vertex = struct {
    pos: [2]f32,                    // Screen position
    uv: [2]f32 = .{ 1.0, 0.0 },    // Texture coordinates (default for non-textured)
    color: Color = .{ 255, 255, 255, 1 },  // Vertex color
};
```

## Known Issues & TODOs

### Known Bugs (from source code)

1. **glfwTerminate crash** (main.zig)

   ```zig
   // BUG: glfwTerminate causing panic when window closes
   // defer glfw.glfwTerminate();
   ```

   - Currently commented out to prevent crash
   - Needs investigation

### Completed Features (Phase 1)

- [x] Mouse click/button input (left button)
- [x] Keyboard input (character input, key presses)
- [x] Modifier keys (Ctrl, Alt, Shift, Super)
- [x] Text input widget with full editing support
- [x] Checkbox widget
- [x] Interactive buttons with hover/click detection
- [x] Rounded rectangle rendering
- [x] Multi-size font caching
- [x] Multi-texture batching

### Missing Features (Phase 2+)

- [ ] Right/middle mouse button support
- [ ] Mouse scroll/wheel input
- [ ] Additional widgets (radio button, slider, dropdown, etc.)
- [ ] Layout system (currently manual positioning)
- [ ] Window/panel system
- [ ] Clipping/scissor rectangles
- [ ] Themes/styling system
- [ ] Multi-font support (different font families)
- [ ] Unicode support (currently ASCII only)
- [ ] Z-ordering/depth

### Renderer Limitations

- Limited texture batching (functional but not fully optimized)
- No draw call instancing
- Full buffer upload each frame (no dirty tracking)
- No frustum culling or off-screen widget culling

## Testing & Debugging

### Running the Application

```bash
zig build run
```

Expected output: A 1920x1080 window with a button labeled "hello world" at position (30, 30).

### OpenGL Debugging

The renderer includes comprehensive error checking via `checkGlError()` calls after each OpenGL operation. Errors are printed to stderr with location information.

### Common Issues

1. **Black screen**: Check shader compilation logs
2. **Missing text**: Font loading may have failed, check file path
3. **Crash on startup**: OpenGL context creation failure - check drivers

## Adding New Dependencies

1. Add dependency to `build.zig.zon`:

   ```zig
   .dependencies = .{
       .package_name = .{
           .url = "git+https://...",
           .hash = "...",  // Leave blank first, zig will provide
       },
   }
   ```

2. Update `build.zig`:

   ```zig
   const dep = b.dependency("package_name", .{
       .target = target,
       .optimize = optimize,
   });
   exe.root_module.linkLibrary(dep.artifact("artifact_name"));
   ```

3. Run `zig build` - Zig will compute the hash if missing

## Recent Development Activity

Based on git history (most recent first):

- `8ebc964` - Copy/paste support for text input widget
- `598d01f` - WIP input widget development
- `0ab800f` - Modifier keys + text selection in input widget
- `c6371f5` - Code simplification
- `cca3cb8` - Basic input component implementation
- `ec56cde` - Text rendering fully working
- `a95857f` - Progress on text rendering
- `aff2d11` - Shader fixes
- `a3422aa` - Started font rendering implementation
- `2672f3c` - OpenGL rendering infrastructure

**Development pattern**: Incremental feature development. Foundation (rendering, fonts) completed in Phase 1. Currently finishing Phase 1 (interactive widgets) with comprehensive text input support. Next focus: Phase 2 layout system.

## AI Assistant Guidelines

### When Making Changes

1. **Always read before modifying** - Use the Read tool on files before editing
2. **Follow existing patterns** - Match the style and structure of existing code
3. **Test rendering changes** - Changes to shaders, renderers, or draw list affect output
4. **Memory safety** - Ensure proper cleanup with defer, check allocations
5. **Error handling** - Use error unions, don't ignore errors

### Common Tasks

**Adding a shape primitive:**

1. Add method to `DrawList` (draw_list.zig)
2. Follow pattern of `addRect` - create vertices, append to buffers
3. Test in main loop

**Modifying rendering:**

1. Changes to vertex format require shader updates
2. Update `Vertex` struct in shapes.zig
3. Update vertex attribute setup in opengl.zig:79-94
4. Update shader inputs in opengl.zig:98-127

**Adding input support:**

1. Add state to `GuiContext`
2. Update `input.updateInput()` to poll GLFW
3. Use in widget functions

### Performance Considerations

- DrawList clears but retains capacity - good for stable frame-to-frame usage
- Font atlas created once at startup - no runtime texture updates
- All rendering goes through one shader - minimal state changes
- Current implementation: no draw call batching or optimization

### Code Quality

- Use `zig fmt` for formatting (when available)
- Prefer explicit over implicit (allocators, types)
- Document complex algorithms
- Add error checking for OpenGL calls using `checkGlError()`

## Future Architecture Considerations

As the library grows, consider:

1. **Texture management** - Multi-texture support, texture atlas for UI elements
2. **Draw call batching** - Group by texture/shader to minimize state changes
3. **Clipping stack** - For nested UI elements
4. **Layout engine** - Automatic positioning and sizing
5. **Event system** - Mouse/keyboard events propagated to widgets
6. **State management** - Widget state persistence across frames
7. **Styling/theming** - Separate visual style from widget logic

## Resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [GLFW Documentation](https://www.glfw.org/documentation.html)
- [OpenGL 3.3 Reference](https://www.khronos.org/registry/OpenGL-Refpages/gl4/)
- [stb_truetype Documentation](https://github.com/nothings/stb/blob/master/stb_truetype.h)

---

**Last Updated**: 2025-11-22
**Project Status**: Phase 1 (~80% Complete) - Interactive widgets functional
**Maintainer**: jackparsonss
