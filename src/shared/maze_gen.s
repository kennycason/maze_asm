// ============================================================================
// maze_gen.s - Maze generation using recursive backtracking
// ============================================================================
// Generates a perfect maze (one path between any two points).
// Algorithm: Recursive backtracking with randomized direction order.
//
// Functions:
//   maze_init       - Initialize maze memory
//   maze_generate   - Generate maze using recursive backtracking
//   maze_free       - Free maze memory
//   maze_get_tile   - Get tile value at (x, y)
//   maze_get_data   - Get pointer to maze data
// ============================================================================

.global _maze_init
.global _maze_generate
.global _maze_free
.global _maze_get_tile
.global _maze_get_data
.global _maze_width
.global _maze_height
.global _maze_start_x
.global _maze_start_y
.global _maze_end_x
.global _maze_end_y

.include "include/constants.inc"

.text

// Maze constants
.set TILE_SIZE,     16
.set MAZE_WIDTH,    41          // 41*16=656 (window width)
.set MAZE_HEIGHT,   31          // 31*16=496 (window height)

// Tile values
.set TILE_WALL,     1
.set TILE_PATH,     0
.set TILE_START,    2
.set TILE_END,      3

// Direction offsets: N, E, S, W
// dx: 0, 1, 0, -1
// dy: -1, 0, 1, 0

// ============================================================================
// _maze_init - Initialize maze
// Output: x0 = 0 on success, -1 on failure
// ============================================================================
.align 4
_maze_init:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Allocate maze data
    mov     x0, #(MAZE_WIDTH * MAZE_HEIGHT)
    bl      _malloc
    cbz     x0, init_fail
    
    adrp    x1, _maze_data@PAGE
    add     x1, x1, _maze_data@PAGEOFF
    str     x0, [x1]
    
    // Store dimensions
    adrp    x1, _maze_width@PAGE
    add     x1, x1, _maze_width@PAGEOFF
    mov     w2, #MAZE_WIDTH
    str     w2, [x1]
    
    adrp    x1, _maze_height@PAGE
    add     x1, x1, _maze_height@PAGEOFF
    mov     w2, #MAZE_HEIGHT
    str     w2, [x1]
    
    // Allocate stack for recursive generation (avoid actual recursion)
    // Stack size: width * height * 8 bytes (x, y pairs)
    mov     x0, #(MAZE_WIDTH * MAZE_HEIGHT * 8)
    bl      _malloc
    cbz     x0, init_fail
    
    adrp    x1, _gen_stack@PAGE
    add     x1, x1, _gen_stack@PAGEOFF
    str     x0, [x1]
    
    mov     x0, #0
    b       init_done

init_fail:
    mov     x0, #-1
    
init_done:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _maze_generate - Generate maze using iterative backtracking
// ============================================================================
.align 4
_maze_generate:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!
    stp     x27, x28, [sp, #-16]!
    
    // Get maze data pointer
    adrp    x19, _maze_data@PAGE
    add     x19, x19, _maze_data@PAGEOFF
    ldr     x19, [x19]
    
    // Get stack pointer
    adrp    x20, _gen_stack@PAGE
    add     x20, x20, _gen_stack@PAGEOFF
    ldr     x20, [x20]
    
    // Fill maze with walls
    mov     x0, x19
    mov     w1, #TILE_WALL
    mov     x2, #(MAZE_WIDTH * MAZE_HEIGHT)
    bl      _memset
    
    // Initialize: start at (1, 1)
    mov     w21, #1                  // current x
    mov     w22, #1                  // current y
    mov     w23, #0                  // stack pointer (count)
    
    // Mark starting cell as path
    mov     w0, #MAZE_WIDTH
    mul     w0, w22, w0
    add     w0, w0, w21
    strb    wzr, [x19, x0]           // TILE_PATH = 0
    
    // Push start position to stack
    lsl     x1, x23, #3              // offset = index * 8
    add     x1, x20, x1
    str     w21, [x1]
    str     w22, [x1, #4]
    add     w23, w23, #1

gen_loop:
    // While stack not empty
    cbz     w23, gen_done
    
    // Get current position from top of stack
    sub     w23, w23, #1             // Pop
    lsl     x1, x23, #3
    add     x1, x20, x1
    ldr     w21, [x1]                // x
    ldr     w22, [x1, #4]            // y
    
    // Shuffle directions (Fisher-Yates on 4 elements)
    // Store directions in w24-w27: 0=N, 1=E, 2=S, 3=W
    mov     w24, #0
    mov     w25, #1
    mov     w26, #2
    mov     w27, #3
    
    // Shuffle
    bl      _rand
    and     w0, w0, #3
    // Swap position 3 with random 0-3
    cmp     w0, #0
    b.eq    swap3_0
    cmp     w0, #1
    b.eq    swap3_1
    cmp     w0, #2
    b.eq    swap3_2
    b       shuffle2
swap3_0:
    mov     w28, w27
    mov     w27, w24
    mov     w24, w28
    b       shuffle2
swap3_1:
    mov     w28, w27
    mov     w27, w25
    mov     w25, w28
    b       shuffle2
swap3_2:
    mov     w28, w27
    mov     w27, w26
    mov     w26, w28
    
shuffle2:
    bl      _rand
    and     w0, w0, #3
    cmp     w0, #3
    b.ge    shuffle2
    cmp     w0, #0
    b.eq    swap2_0
    cmp     w0, #1
    b.eq    swap2_1
    b       shuffle1
swap2_0:
    mov     w28, w26
    mov     w26, w24
    mov     w24, w28
    b       shuffle1
swap2_1:
    mov     w28, w26
    mov     w26, w25
    mov     w25, w28
    
shuffle1:
    bl      _rand
    and     w0, w0, #1
    cbz     w0, try_dirs
    mov     w28, w25
    mov     w25, w24
    mov     w24, w28
    
try_dirs:
    // Try each direction
    // Directions are in w24, w25, w26, w27
    mov     w28, #0                  // direction index
    
try_dir_loop:
    cmp     w28, #4
    b.ge    gen_loop                 // No valid direction, backtrack
    
    // Get direction from shuffled array
    cmp     w28, #0
    b.eq    get_dir0
    cmp     w28, #1
    b.eq    get_dir1
    cmp     w28, #2
    b.eq    get_dir2
    mov     w0, w27
    b       have_dir
get_dir0:
    mov     w0, w24
    b       have_dir
get_dir1:
    mov     w0, w25
    b       have_dir
get_dir2:
    mov     w0, w26
    
have_dir:
    // Calculate new position (2 cells away)
    // dx: 0, 1, 0, -1 for N, E, S, W
    // dy: -1, 0, 1, 0
    mov     w1, w21                  // nx = x
    mov     w2, w22                  // ny = y
    
    cmp     w0, #0                   // North
    b.ne    check_east
    sub     w2, w2, #2
    b       check_valid
check_east:
    cmp     w0, #1                   // East
    b.ne    check_south
    add     w1, w1, #2
    b       check_valid
check_south:
    cmp     w0, #2                   // South
    b.ne    check_west
    add     w2, w2, #2
    b       check_valid
check_west:
    sub     w1, w1, #2               // West
    
check_valid:
    // Bounds check
    cmp     w1, #1
    b.lt    next_dir
    cmp     w1, #(MAZE_WIDTH - 1)
    b.ge    next_dir
    cmp     w2, #1
    b.lt    next_dir
    cmp     w2, #(MAZE_HEIGHT - 1)
    b.ge    next_dir
    
    // Check if cell is unvisited (still wall)
    mov     w3, #MAZE_WIDTH
    mul     w3, w2, w3
    add     w3, w3, w1
    ldrb    w4, [x19, x3]
    cmp     w4, #TILE_WALL
    b.ne    next_dir
    
    // Valid! Push current position back to stack
    lsl     x5, x23, #3
    add     x5, x20, x5
    str     w21, [x5]
    str     w22, [x5, #4]
    add     w23, w23, #1
    
    // Carve path: mark cell between as path
    add     w5, w21, w1
    lsr     w5, w5, #1               // mid_x = (x + nx) / 2
    add     w6, w22, w2
    lsr     w6, w6, #1               // mid_y = (y + ny) / 2
    mov     w3, #MAZE_WIDTH
    mul     w3, w6, w3
    add     w3, w3, w5
    strb    wzr, [x19, x3]           // Mark as path
    
    // Mark new cell as path
    mov     w3, #MAZE_WIDTH
    mul     w3, w2, w3
    add     w3, w3, w1
    strb    wzr, [x19, x3]           // Mark as path
    
    // Push new position
    lsl     x5, x23, #3
    add     x5, x20, x5
    str     w1, [x5]
    str     w2, [x5, #4]
    add     w23, w23, #1
    
    b       gen_loop
    
next_dir:
    add     w28, w28, #1
    b       try_dir_loop

gen_done:
    // Set start position (1, 1)
    mov     w0, #1
    adrp    x1, _maze_start_x@PAGE
    add     x1, x1, _maze_start_x@PAGEOFF
    str     w0, [x1]
    adrp    x1, _maze_start_y@PAGE
    add     x1, x1, _maze_start_y@PAGEOFF
    str     w0, [x1]
    
    // Mark start
    mov     w0, #(MAZE_WIDTH + 1)    // 1*width + 1
    mov     w1, #TILE_START
    strb    w1, [x19, x0]
    
    // Set end position (bottom-right area, find a path cell)
    mov     w0, #(MAZE_WIDTH - 2)
    adrp    x1, _maze_end_x@PAGE
    add     x1, x1, _maze_end_x@PAGEOFF
    str     w0, [x1]
    mov     w0, #(MAZE_HEIGHT - 2)
    adrp    x1, _maze_end_y@PAGE
    add     x1, x1, _maze_end_y@PAGEOFF
    str     w0, [x1]
    
    // Find valid end cell near bottom-right
    mov     w21, #(MAZE_WIDTH - 2)
    mov     w22, #(MAZE_HEIGHT - 2)
find_end:
    mov     w0, #MAZE_WIDTH
    mul     w0, w22, w0
    add     w0, w0, w21
    ldrb    w1, [x19, x0]
    cbz     w1, found_end            // Found path cell
    sub     w21, w21, #1
    cmp     w21, #1
    b.gt    find_end
    mov     w21, #(MAZE_WIDTH - 2)
    sub     w22, w22, #1
    cmp     w22, #1
    b.gt    find_end
    // Fallback: use (width-2, height-2) anyway
    mov     w21, #(MAZE_WIDTH - 2)
    mov     w22, #(MAZE_HEIGHT - 2)
    
found_end:
    adrp    x1, _maze_end_x@PAGE
    add     x1, x1, _maze_end_x@PAGEOFF
    str     w21, [x1]
    adrp    x1, _maze_end_y@PAGE
    add     x1, x1, _maze_end_y@PAGEOFF
    str     w22, [x1]
    
    // Mark end
    mov     w0, #MAZE_WIDTH
    mul     w0, w22, w0
    add     w0, w0, w21
    mov     w1, #TILE_END
    strb    w1, [x19, x0]
    
    ldp     x27, x28, [sp], #16
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _maze_free - Free maze memory
// ============================================================================
.align 4
_maze_free:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, _maze_data@PAGE
    add     x0, x0, _maze_data@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, 1f
    bl      _free
    adrp    x0, _maze_data@PAGE
    add     x0, x0, _maze_data@PAGEOFF
    str     xzr, [x0]
    
1:
    adrp    x0, _gen_stack@PAGE
    add     x0, x0, _gen_stack@PAGEOFF
    ldr     x0, [x0]
    cbz     x0, 2f
    bl      _free
    adrp    x0, _gen_stack@PAGE
    add     x0, x0, _gen_stack@PAGEOFF
    str     xzr, [x0]
    
2:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// _maze_get_tile - Get tile value
// Input:  w0 = x, w1 = y
// Output: w0 = tile value, or 1 (wall) if out of bounds
// ============================================================================
.align 4
_maze_get_tile:
    cmp     w0, #0
    b.lt    tile_wall
    cmp     w0, #MAZE_WIDTH
    b.ge    tile_wall
    cmp     w1, #0
    b.lt    tile_wall
    cmp     w1, #MAZE_HEIGHT
    b.ge    tile_wall
    
    mov     w2, #MAZE_WIDTH
    mul     w2, w1, w2
    add     w2, w2, w0
    
    adrp    x3, _maze_data@PAGE
    add     x3, x3, _maze_data@PAGEOFF
    ldr     x3, [x3]
    ldrb    w0, [x3, x2]
    ret
    
tile_wall:
    mov     w0, #TILE_WALL
    ret

// ============================================================================
// _maze_get_data - Get pointer to maze data
// ============================================================================
.align 4
_maze_get_data:
    adrp    x0, _maze_data@PAGE
    add     x0, x0, _maze_data@PAGEOFF
    ldr     x0, [x0]
    ret

// ============================================================================
// Data
// ============================================================================
.data
.align 8
_maze_data:     .quad 0
_gen_stack:     .quad 0
_maze_width:    .word MAZE_WIDTH
_maze_height:   .word MAZE_HEIGHT
_maze_start_x:  .word 1
_maze_start_y:  .word 1
_maze_end_x:    .word (MAZE_WIDTH - 2)
_maze_end_y:    .word (MAZE_HEIGHT - 2)
