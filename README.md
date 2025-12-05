# Maze ASM

![Screenshot](screenshot.png)

[▶️ Watch Demo](maze_asm.mp4)
[▶️ Watch Color Demo](maze_asm_colors.mp4)

A maze game written entirely in ARM64 assembly for macOS. Navigate through randomly generated mazes using classic recursive backtracking.

## About

This project demonstrates building a complete graphical application in pure assembly language without relying on high-level graphics libraries like SDL. Everything from window management to pixel rendering is implemented using native macOS frameworks called directly from assembly via the Objective-C runtime.

### Why Assembly?

- Learn how graphics really work at the lowest level
- Understand CPU architecture and calling conventions
- Direct interaction with the operating system
- No abstraction layers hiding the details

## Features

- **Recursive Backtracking Maze Generation** - Creates perfect mazes with exactly one path between any two points
- **Software Rasterizer** - Custom pixel-by-pixel drawing routines
  - Bresenham's line algorithm
  - Midpoint circle algorithm
  - Filled and outlined rectangles/circles
- **Native macOS Integration** - No SDL or external graphics libraries
  - Cocoa window management via `objc_msgSend`
  - CoreGraphics for display and keyboard input
  - Direct system calls for console output
- **Smooth Controls** - Movement cooldown for precise single-tile navigation

## Controls

| Key | Action |
|-----|--------|
| ↑ / W | Move up |
| ↓ / S | Move down |
| ← / A | Move left |
| → / D | Move right |
| R | Generate new maze |
| ESC / Q | Quit |

## Building

### Requirements

- macOS (Apple Silicon / ARM64)
- Xcode Command Line Tools

### Build & Run

```bash
make run
```

## Project Structure

```
maze_asm/
├── include/
│   └── constants.inc          # Shared constants and key mappings
├── src/
│   ├── maze.s                 # Main game loop and rendering
│   ├── shared/
│   │   ├── maze_gen.s         # Maze generation (recursive backtracking)
│   │   └── raster.s           # Software rasterizer (platform-independent)
│   └── platform/
│       └── macos/
│           ├── window.s       # Cocoa window management
│           ├── keyboard.s     # CoreGraphics keyboard input
│           ├── timing.s       # Frame timing (usleep)
│           └── print.s        # Console output (syscalls)
├── build/                     # Compiled output (build/maze)
├── Makefile
└── README.md
```

### Maze Algorithm

The maze uses iterative backtracking (stack-based to avoid deep recursion):

1. Start with a grid of walls
2. Pick starting cell, mark as path
3. Randomly shuffle directions (N, E, S, W)
4. For each direction, if cell 2 steps away is unvisited:
   - Carve path to that cell
   - Push current position to stack
   - Move to new cell
5. If no valid directions, pop from stack (backtrack)
6. Repeat until stack is empty

This generates a "perfect maze" - exactly one path between any two points.

## Technical Details

### Native Implementation Stack

| Layer | Implementation |
|-------|----------------|
| Window | Cocoa (`NSApplication`, `NSWindow`, `NSView`, `CALayer`) |
| Display | CoreGraphics (`CGImage`, `CGDataProvider`) |
| Input | CoreGraphics (`CGEventSourceKeyState`) |
| Drawing | Custom assembly (framebuffer manipulation) |
| Timing | libc `usleep` |
| Console | macOS syscall `SYS_WRITE` |

### ARM64 Calling Convention

```
Arguments:     x0-x7 (w0-w7 for 32-bit)
Return value:  x0
Callee-saved:  x19-x28
Frame pointer: x29
Link register: x30
Stack:         16-byte aligned
```

## Graphics Primitives

The software rasterizer provides:

- `_raster_init` / `_raster_free` - Framebuffer management
- `_raster_set_color` - Set RGBA drawing color
- `_raster_clear` - Fill framebuffer with current color
- `_raster_plot` - Draw single pixel
- `_raster_line` - Bresenham's line algorithm
- `_raster_rect` / `_raster_rect_outline` - Rectangles
- `_raster_circle` / `_raster_circle_filled` - Midpoint circle algorithm

## License

MIT
