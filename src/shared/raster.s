// ============================================================================
// raster.s - Software rasterization engine
// ============================================================================
// Software rasterizer with pixel-level drawing routines.
// 
// Functions:
//   raster_init       - Allocate framebuffer
//   raster_free       - Free framebuffer
//   raster_clear      - Clear buffer with color
//   raster_plot       - Plot single pixel
//   raster_line       - Bresenham's line algorithm
//   raster_rect       - Filled rectangle
//   raster_rect_outline - Rectangle outline
//   raster_circle     - Midpoint circle algorithm
//   raster_circle_filled - Filled circle
// ============================================================================

.global _raster_init
.global _raster_free
.global _raster_clear
.global _raster_plot
.global _raster_line
.global _raster_rect
.global _raster_rect_outline
.global _raster_circle
.global _raster_circle_filled
.global _raster_set_color
.global _raster_get_buffer
.global _framebuffer
.global _fb_width
.global _fb_height
.global _fb_pitch

.include "include/constants.inc"

.text

// ============================================================================
// _raster_init - Initialize framebuffer
// Input:  w0 = width
//         w1 = height
// Output: x0 = pointer to framebuffer, or 0 on failure
// ============================================================================
.align 4
_raster_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Save dimensions
    mov     w19, w0                  // width
    mov     w20, w1                  // height
    
    // Store dimensions
    adrp    x2, _fb_width@PAGE
    add     x2, x2, _fb_width@PAGEOFF
    str     w19, [x2]
    
    adrp    x2, _fb_height@PAGE
    add     x2, x2, _fb_height@PAGEOFF
    str     w20, [x2]
    
    // Calculate pitch (width * 4 bytes per pixel)
    lsl     w21, w19, #2             // pitch = width * 4
    adrp    x2, _fb_pitch@PAGE
    add     x2, x2, _fb_pitch@PAGEOFF
    str     w21, [x2]
    
    // Calculate total size (pitch * height)
    mul     w22, w21, w20            // size = pitch * height
    
    // Allocate memory via malloc
    mov     x0, x22
    bl      _malloc
    
    // Store framebuffer pointer
    adrp    x1, _framebuffer@PAGE
    add     x1, x1, _framebuffer@PAGEOFF
    str     x0, [x1]
    
    // Initialize default color to white
    mov     w1, #255
    adrp    x2, _current_r@PAGE
    add     x2, x2, _current_r@PAGEOFF
    strb    w1, [x2]
    adrp    x2, _current_g@PAGE
    add     x2, x2, _current_g@PAGEOFF
    strb    w1, [x2]
    adrp    x2, _current_b@PAGE
    add     x2, x2, _current_b@PAGEOFF
    strb    w1, [x2]
    adrp    x2, _current_a@PAGE
    add     x2, x2, _current_a@PAGEOFF
    strb    w1, [x2]
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_free - Free framebuffer
// ============================================================================
.align 4
_raster_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, _framebuffer@PAGE
    add     x0, x0, _framebuffer@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, 1f
    bl      _free
    
    // Clear pointer
    adrp    x0, _framebuffer@PAGE
    add     x0, x0, _framebuffer@PAGEOFF
    str     xzr, [x0]
    
1:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_get_buffer - Get framebuffer pointer
// Output: x0 = framebuffer pointer
// ============================================================================
.align 4
_raster_get_buffer:
    adrp    x0, _framebuffer@PAGE
    add     x0, x0, _framebuffer@PAGEOFF
    ldr     x0, [x0]
    ret

// ============================================================================
// _raster_set_color - Set current drawing color
// Input:  w0 = red, w1 = green, w2 = blue, w3 = alpha
// ============================================================================
.align 4
_raster_set_color:
    adrp    x4, _current_r@PAGE
    add     x4, x4, _current_r@PAGEOFF
    strb    w0, [x4]
    adrp    x4, _current_g@PAGE
    add     x4, x4, _current_g@PAGEOFF
    strb    w1, [x4]
    adrp    x4, _current_b@PAGE
    add     x4, x4, _current_b@PAGEOFF
    strb    w2, [x4]
    adrp    x4, _current_a@PAGE
    add     x4, x4, _current_a@PAGEOFF
    strb    w3, [x4]
    ret

// ============================================================================
// _raster_clear - Clear framebuffer with current color
// ============================================================================
.align 4
_raster_clear:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    
    // Get framebuffer
    adrp    x19, _framebuffer@PAGE
    add     x19, x19, _framebuffer@PAGEOFF
    ldr     x19, [x19]
    cbz     x19, clear_done
    
    // Build pixel value (0xAABBGGRR for RGBA byte order in little-endian)
    adrp    x0, _current_a@PAGE
    add     x0, x0, _current_a@PAGEOFF
    ldrb    w0, [x0]
    lsl     w20, w0, #24             // A << 24
    
    adrp    x0, _current_b@PAGE
    add     x0, x0, _current_b@PAGEOFF
    ldrb    w0, [x0]
    orr     w20, w20, w0, lsl #16    // | B << 16
    
    adrp    x0, _current_g@PAGE
    add     x0, x0, _current_g@PAGEOFF
    ldrb    w0, [x0]
    orr     w20, w20, w0, lsl #8     // | G << 8
    
    adrp    x0, _current_r@PAGE
    add     x0, x0, _current_r@PAGEOFF
    ldrb    w0, [x0]
    orr     w20, w20, w0             // | R
    
    // Get total pixels
    adrp    x0, _fb_width@PAGE
    add     x0, x0, _fb_width@PAGEOFF
    ldr     w0, [x0]
    adrp    x1, _fb_height@PAGE
    add     x1, x1, _fb_height@PAGEOFF
    ldr     w1, [x1]
    mul     w1, w0, w1               // total pixels
    
    // Fill loop
    mov     x0, x19                  // buffer pointer
clear_loop:
    cbz     w1, clear_done
    str     w20, [x0], #4            // Store pixel, advance
    sub     w1, w1, #1
    b       clear_loop
    
clear_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_plot - Plot a single pixel
// Input:  w0 = x, w1 = y
// ============================================================================
.align 4
_raster_plot:
    // Bounds check
    adrp    x2, _fb_width@PAGE
    add     x2, x2, _fb_width@PAGEOFF
    ldr     w2, [x2]
    cmp     w0, w2
    b.ge    plot_skip
    cmp     w0, #0
    b.lt    plot_skip
    
    adrp    x2, _fb_height@PAGE
    add     x2, x2, _fb_height@PAGEOFF
    ldr     w2, [x2]
    cmp     w1, w2
    b.ge    plot_skip
    cmp     w1, #0
    b.lt    plot_skip
    
    // Calculate offset: (y * pitch) + (x * 4)
    adrp    x2, _fb_pitch@PAGE
    add     x2, x2, _fb_pitch@PAGEOFF
    ldr     w2, [x2]
    mul     w3, w1, w2               // y * pitch
    add     w3, w3, w0, lsl #2       // + x * 4
    
    // Get framebuffer
    adrp    x4, _framebuffer@PAGE
    add     x4, x4, _framebuffer@PAGEOFF
    ldr     x4, [x4]
    
    // Build pixel (0xAABBGGRR for RGBA byte order in little-endian)
    adrp    x5, _current_a@PAGE
    add     x5, x5, _current_a@PAGEOFF
    ldrb    w5, [x5]
    lsl     w6, w5, #24
    
    adrp    x5, _current_b@PAGE
    add     x5, x5, _current_b@PAGEOFF
    ldrb    w5, [x5]
    orr     w6, w6, w5, lsl #16
    
    adrp    x5, _current_g@PAGE
    add     x5, x5, _current_g@PAGEOFF
    ldrb    w5, [x5]
    orr     w6, w6, w5, lsl #8
    
    adrp    x5, _current_r@PAGE
    add     x5, x5, _current_r@PAGEOFF
    ldrb    w5, [x5]
    orr     w6, w6, w5
    
    // Store pixel
    str     w6, [x4, x3]
    
plot_skip:
    ret

// ============================================================================
// _raster_line - Draw line using Bresenham's algorithm
// Input:  w0 = x0, w1 = y0, w2 = x1, w3 = y1
// ============================================================================
.align 4
_raster_line:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!
    stp     x27, x28, [sp, #-16]!
    
    // Save coordinates
    mov     w19, w0                  // x0 (current x)
    mov     w20, w1                  // y0 (current y)
    mov     w21, w2                  // x1
    mov     w22, w3                  // y1
    
    // Calculate dx = abs(x1 - x0)
    sub     w23, w21, w19            // dx = x1 - x0
    cmp     w23, #0
    cneg    w24, w23, lt             // abs(dx)
    
    // Calculate dy = -abs(y1 - y0)
    sub     w25, w22, w20            // dy = y1 - y0
    cmp     w25, #0
    cneg    w25, w25, gt             // -abs(dy)
    
    // sx = x0 < x1 ? 1 : -1
    mov     w26, #1
    cmp     w19, w21
    cneg    w26, w26, ge             // sx
    
    // sy = y0 < y1 ? 1 : -1
    mov     w27, #1
    cmp     w20, w22
    cneg    w27, w27, ge             // sy
    
    // err = dx + dy
    add     w28, w24, w25            // err
    
line_loop:
    // Plot current point
    mov     w0, w19
    mov     w1, w20
    bl      _raster_plot
    
    // Check if done (x == x1 && y == y1)
    cmp     w19, w21
    ccmp    w20, w22, #0, eq
    b.eq    line_done
    
    // e2 = 2 * err
    lsl     w0, w28, #1              // e2 = err * 2
    
    // if (e2 >= dy) { err += dy; x += sx; }
    cmp     w0, w25
    b.lt    line_check_dx
    add     w28, w28, w25            // err += dy
    add     w19, w19, w26            // x += sx
    
line_check_dx:
    // if (e2 <= dx) { err += dx; y += sy; }
    lsl     w0, w28, #1              // recalc e2 (err may have changed)
    sub     w0, w0, w25              // adjust for the add we may have done
    cmp     w0, w24
    b.gt    line_loop
    add     w28, w28, w24            // err += dx
    add     w20, w20, w27            // y += sy
    
    b       line_loop
    
line_done:
    ldp     x27, x28, [sp], #16
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_rect - Draw filled rectangle
// Input:  w0 = x, w1 = y, w2 = width, w3 = height
// ============================================================================
.align 4
_raster_rect:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    mov     w19, w0                  // start x
    mov     w20, w1                  // start y
    add     w21, w0, w2              // end x
    add     w22, w1, w3              // end y
    mov     w23, w20                 // current y
    
rect_y_loop:
    cmp     w23, w22
    b.ge    rect_done
    
    mov     w24, w19                 // current x
    
rect_x_loop:
    cmp     w24, w21
    b.ge    rect_next_row
    
    mov     w0, w24
    mov     w1, w23
    bl      _raster_plot
    
    add     w24, w24, #1
    b       rect_x_loop
    
rect_next_row:
    add     w23, w23, #1
    b       rect_y_loop
    
rect_done:
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_rect_outline - Draw rectangle outline
// Input:  w0 = x, w1 = y, w2 = width, w3 = height
// ============================================================================
.align 4
_raster_rect_outline:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    mov     w19, w0                  // x
    mov     w20, w1                  // y
    mov     w21, w2                  // width
    mov     w22, w3                  // height
    
    // Top line
    mov     w0, w19
    mov     w1, w20
    add     w2, w19, w21
    sub     w2, w2, #1
    mov     w3, w20
    bl      _raster_line
    
    // Bottom line
    mov     w0, w19
    add     w1, w20, w22
    sub     w1, w1, #1
    add     w2, w19, w21
    sub     w2, w2, #1
    add     w3, w20, w22
    sub     w3, w3, #1
    bl      _raster_line
    
    // Left line
    mov     w0, w19
    mov     w1, w20
    mov     w2, w19
    add     w3, w20, w22
    sub     w3, w3, #1
    bl      _raster_line
    
    // Right line
    add     w0, w19, w21
    sub     w0, w0, #1
    mov     w1, w20
    add     w2, w19, w21
    sub     w2, w2, #1
    add     w3, w20, w22
    sub     w3, w3, #1
    bl      _raster_line
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_circle - Draw circle outline (midpoint algorithm)
// Input:  w0 = cx, w1 = cy, w2 = radius
// ============================================================================
.align 4
_raster_circle:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    mov     w19, w0                  // cx
    mov     w20, w1                  // cy
    mov     w21, w2                  // radius
    
    mov     w22, #0                  // x = 0
    mov     w23, w21                 // y = radius
    mov     w24, #1
    sub     w24, w24, w21            // d = 1 - radius
    
circle_loop:
    cmp     w22, w23
    b.gt    circle_done
    
    // Plot 8 symmetric points
    // (cx + x, cy + y)
    add     w0, w19, w22
    add     w1, w20, w23
    bl      _raster_plot
    
    // (cx - x, cy + y)
    sub     w0, w19, w22
    add     w1, w20, w23
    bl      _raster_plot
    
    // (cx + x, cy - y)
    add     w0, w19, w22
    sub     w1, w20, w23
    bl      _raster_plot
    
    // (cx - x, cy - y)
    sub     w0, w19, w22
    sub     w1, w20, w23
    bl      _raster_plot
    
    // (cx + y, cy + x)
    add     w0, w19, w23
    add     w1, w20, w22
    bl      _raster_plot
    
    // (cx - y, cy + x)
    sub     w0, w19, w23
    add     w1, w20, w22
    bl      _raster_plot
    
    // (cx + y, cy - x)
    add     w0, w19, w23
    sub     w1, w20, w22
    bl      _raster_plot
    
    // (cx - y, cy - x)
    sub     w0, w19, w23
    sub     w1, w20, w22
    bl      _raster_plot
    
    // Update decision parameter
    cmp     w24, #0
    b.ge    circle_d_positive
    
    // d < 0: d = d + 2*x + 3
    add     w24, w24, w22, lsl #1
    add     w24, w24, #3
    b       circle_next
    
circle_d_positive:
    // d >= 0: d = d + 2*(x - y) + 5
    sub     w0, w22, w23
    add     w24, w24, w0, lsl #1
    add     w24, w24, #5
    sub     w23, w23, #1             // y--
    
circle_next:
    add     w22, w22, #1             // x++
    b       circle_loop
    
circle_done:
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _raster_circle_filled - Draw filled circle
// Input:  w0 = cx, w1 = cy, w2 = radius
// ============================================================================
.align 4
_raster_circle_filled:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    mov     w19, w0                  // cx
    mov     w20, w1                  // cy
    mov     w21, w2                  // radius
    
    mov     w22, #0                  // x = 0
    mov     w23, w21                 // y = radius
    mov     w24, #1
    sub     w24, w24, w21            // d = 1 - radius
    
filled_circle_loop:
    cmp     w22, w23
    b.gt    filled_circle_done
    
    // Draw horizontal lines for filled circle
    // Line from (cx - x, cy + y) to (cx + x, cy + y)
    sub     w0, w19, w22
    add     w1, w20, w23
    add     w2, w19, w22
    mov     w3, w1
    bl      _raster_line
    
    // Line from (cx - x, cy - y) to (cx + x, cy - y)
    sub     w0, w19, w22
    sub     w1, w20, w23
    add     w2, w19, w22
    mov     w3, w1
    bl      _raster_line
    
    // Line from (cx - y, cy + x) to (cx + y, cy + x)
    sub     w0, w19, w23
    add     w1, w20, w22
    add     w2, w19, w23
    mov     w3, w1
    bl      _raster_line
    
    // Line from (cx - y, cy - x) to (cx + y, cy - x)
    sub     w0, w19, w23
    sub     w1, w20, w22
    add     w2, w19, w23
    mov     w3, w1
    bl      _raster_line
    
    // Update decision parameter
    cmp     w24, #0
    b.ge    filled_d_positive
    
    add     w24, w24, w22, lsl #1
    add     w24, w24, #3
    b       filled_next
    
filled_d_positive:
    sub     w0, w22, w23
    add     w24, w24, w0, lsl #1
    add     w24, w24, #5
    sub     w23, w23, #1
    
filled_next:
    add     w22, w22, #1
    b       filled_circle_loop
    
filled_circle_done:
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// Data section
// ============================================================================
.data
.align 8
_framebuffer:   .quad 0
_fb_width:      .word 0
_fb_height:     .word 0
_fb_pitch:      .word 0

_current_r:     .byte 255
_current_g:     .byte 255
_current_b:     .byte 255
_current_a:     .byte 255

