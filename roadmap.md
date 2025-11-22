# zGUI Development Roadmap

## Vision

A lightweight, immediate-mode GUI library for Zig that enables developers to build simple, performant user interfaces for games and applications.

## Current State (v0.1 - Foundation)

- ✅ OpenGL 3.3 Core renderer
- ✅ TrueType font rendering (ASCII)
- ✅ Multi-size font caching system
- ✅ Basic button widget
- ✅ Mouse cursor tracking and click detection
- ✅ Immediate-mode draw list architecture
- ✅ Rounded rectangle rendering
- ✅ Multi-texture batching support

---

## Phase 1: Core Interaction (v0.2)

**Goal**: Make the GUI interactive and usable for basic applications

### Input System

- [x] Mouse button input (left click)
- [x] Mouse button state tracking (pressed, clicked)
- [x] Keyboard input capture
- [x] Keyboard modifiers (Shift, Ctrl, Alt, Super)
- [x] Text input events for typing
- [x] Platform-specific primary modifier (Cmd/Ctrl)
- [x] Mouse scroll/wheel input
- [x] Right and middle mouse button support

### Widget Interactivity

- [x] Button click detection
- [x] Hover detection for widgets
- [x] Active/focused visual states
- [x] Focus system for text input
- [x] Text selection and editing

### Essential Widgets

- [x] Label (static text)
- [x] Button (interactive)
- [x] Checkbox (with click toggle)
- [x] Text input (single line with full editing support)
  - [x] Cursor movement (arrow keys, Home/End)
  - [x] Text selection (Shift + navigation)
  - [x] Word navigation (Ctrl/Alt + arrows)
  - [x] Copy/Paste (Ctrl/Cmd + C/V)
  - [x] Horizontal scrolling for long text
  - [x] Backspace/Delete
- [ ] Radio button
- [ ] Slider (horizontal and vertical)
- [ ] Image widget (texture display)

### Testing & Examples

- [ ] Interactive demo application
- [ ] Example: Simple form with various widgets
- [ ] Input handling test suite

---

## Phase 2: Layout & Organization (v0.3)

**Goal**: Enable complex UI layouts without manual positioning

### Layout System

- [ ] Automatic layout engine (horizontal/vertical stacking)
- [ ] Padding and margin support
- [ ] Alignment options (left, center, right, top, bottom)
- [ ] Flexible sizing (fixed, fill, fit-content)
- [ ] Grid layout
- [ ] Nested layouts

### Container Widgets

- [ ] Panel (basic container with background)
- [ ] Scrollable container
- [ ] Collapsible section
- [ ] Tab container
- [ ] Split pane (resizable)

### Window System

- [ ] Floating windows
- [ ] Window dragging
- [ ] Window resizing
- [ ] Window minimize/maximize
- [ ] Modal windows
- [ ] Window docking (optional, advanced)

### Clipping & Scissoring

- [ ] Scissor rectangle implementation
- [ ] Clipping stack for nested containers
- [ ] Scroll view clipping

---

## Phase 3: Visual Polish & Theming (v0.4)

**Goal**: Make UIs visually appealing and customizable

### Styling System

- [ ] Theme structure (colors, sizes, spacing)
- [ ] Per-widget style overrides
- [ ] Built-in themes (dark, light, game-style)
- [ ] Style inheritance for nested widgets
- [ ] Runtime theme switching

### Visual Features

- [ ] Rounded corners for rectangles
- [ ] Gradients (linear, radial)
- [ ] Shadows and blur effects
- [ ] Border styling (width, color, style)
- [ ] Background patterns/textures
- [ ] Smooth animations for state transitions
- [ ] Focus system for keyboard navigation (Tab/Arrow keys)

### Advanced Rendering

- [ ] Multi-texture support
- [ ] Texture atlas management
- [ ] Custom shader support
- [ ] Draw call batching optimization
- [ ] Render layer/z-ordering system
- [ ] Alpha blending modes

### Font System Improvements

- [ ] Multi-font support
- [ ] Font fallback chain
- [ ] Unicode support (UTF-8)
- [ ] Font size/weight variations
- [ ] Text styling (bold, italic, underline)
- [ ] Rich text support (mixed styles)

---

## Phase 4: Advanced Widgets (v0.5)

**Goal**: Provide widgets for complex use cases

### Data Widgets

- [ ] List view (virtual scrolling)
- [ ] Tree view (hierarchical data)
- [ ] Table/grid (rows and columns)
- [ ] Dropdown/combo box
- [ ] Multi-line text editor
- [ ] Progress bar
- [ ] Spinner/loading indicator

### Visualization Widgets

- [ ] Graph/chart widgets (line, bar, pie)
- [ ] Color picker
- [ ] Canvas widget (custom drawing)
- [ ] Minimap/overview widget

---

## Phase 5: Library API & Integration (v0.6)

**Goal**: Make zGUI easy to integrate and use in any project

### API Design

- [ ] Clean public API surface
- [ ] Documentation for all public functions
- [ ] Usage examples for every widget
- [ ] Best practices guide
- [ ] Migration guide for version updates

### Build System

- [ ] Package manager integration (Zig package manager)
- [ ] Easy dependency setup
- [ ] Multiple backend support (OpenGL, Vulkan, DirectX)
- [ ] Platform abstraction layer
- [ ] Custom renderer interface

### Backend Options

- [ ] OpenGL 3.3+ (current)
- [ ] OpenGL ES 3.0+ (mobile)
- [ ] Vulkan renderer
- [ ] DirectX 11/12 renderer (Windows)
- [ ] Metal renderer (macOS/iOS)
- [ ] WebGL/WebGPU (WASM)

### Platform Support

- [ ] Windows support
- [ ] MacOS support
- [ ] Linux support
- [ ] Web/WASM support

---

## Phase 6: Performance & Production Ready (v1.0)

**Goal**: Optimize for real-world game engine usage

### Performance Optimization

- [ ] Vertex buffer pooling
- [ ] Dirty region tracking (partial updates)
- [ ] Culling of off-screen widgets
- [ ] Draw call minimization
- [ ] Memory allocation optimization
- [ ] Frame time profiling tools

### Developer Experience

- [ ] Hot-reload support for themes/styles
- [ ] Debug overlay (draw calls, memory, timing)
- [ ] Widget inspector/debugger
- [ ] Error messages and validation
- [ ] Logging and diagnostics

### Quality Assurance

- [ ] Comprehensive test suite
- [ ] Benchmark suite
- [ ] Memory leak testing
- [ ] Cross-platform testing
- [ ] Stress testing (many widgets)

### Documentation

- [ ] Complete API documentation
- [ ] Tutorial series (beginner to advanced)
- [ ] Integration guides (game engines)
- [ ] Performance guide
- [ ] Architecture documentation
- [ ] Contribution guidelines

---

## Milestones

| Version | Milestone   | Target Features                 | Status      |
| ------- | ----------- | ------------------------------- | ----------- |
| v0.1    | Foundation  | Rendering, fonts, basic widgets | ✅ Complete |
| v0.2    | Interactive | Full input, widget interactions | 🔄 Current  |
| v0.3    | Layouts     | Automatic layouts, containers   | 📋 Planned  |
| v0.4    | Polish      | Theming, visual effects         | 📋 Planned  |
| v0.5    | Advanced    | Complex widgets, data views     | 📋 Planned  |
| v0.6    | Integration | Multi-backend, easy API         | 📋 Planned  |
| v1.0    | Production  | Performance, docs, quality      | 📋 Planned  |

---

## Design Principles

### Immediate Mode First

- Clear buffers each frame, rebuild from scratch
- No complex state management
- Simple mental model for users

### Performance Conscious

- Minimize allocations (reuse buffers)
- Batch draw calls when possible
- Cull off-screen elements

### Easy to Integrate

- Minimal dependencies
- Clear, documented API
- Backend agnostic design

### Game Engine Friendly

- Frame-based architecture
- Low overhead
- Customizable rendering

### Zig Idiomatic

- Explicit allocators
- Error unions for failures
- Compile-time configuration where possible

---

## Non-Goals

- **Not a retained-mode GUI**: We won't maintain a persistent widget tree
- **Not a web framework**: No HTML/CSS parsing or DOM
- **Not a 3D UI framework**: Focus on 2D, though 3D positioning may be supported
- **Not a game engine**: Just the UI layer, not physics/audio/etc.

---

## Community & Contribution

### Future Community Goals

- [ ] Public repository with contributing guidelines
- [ ] Issue tracker and roadmap tracking
- [ ] Community showcase of projects using zGUI
- [ ] Plugin/extension system for custom widgets
- [ ] Theme marketplace or repository

---

## Success Metrics

### v1.0 Success Criteria

1. **Performance**: 60fps with 1000+ widgets on modest hardware
2. **Usability**: Complete demo game UI in < 500 lines of code
3. **Documentation**: 100% API coverage, 10+ tutorials
4. **Integration**: Works with at least 2 game engines out of the box
5. **Adoption**: 5+ real projects using zGUI

---

**Last Updated**: 2025-11-22
**Current Phase**: Phase 1 (v0.2 - Core Interaction) - ~80% Complete
**Next Milestone**: Layout system and container widgets (Phase 2)
