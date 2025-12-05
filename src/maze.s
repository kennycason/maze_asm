// ============================================================================
// maze.s - Maze Game (Main Entry Point)
// ============================================================================
// Navigate through randomly generated mazes!
// Controls: Arrow keys/WASD to move, R to regenerate, ESC/Q to quit
// ============================================================================

.global _main

.include "include/constants.inc"

// Tile and player constants
.set TILE_SIZE,     16
.set PLAYER_SIZE,   8
.set PLAYER_OFFSET, 4           // Center player in tile: (16-8)/2

.text

// ============================================================================
// _main - Entry point
// ============================================================================
.align 4
_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x0, msg_init@PAGE
    add     x0, x0, msg_init@PAGEOFF
    bl      _print_str
    bl      _print_newline
    
    // Seed random number generator
    mov     x0, #0
    bl      _time
    bl      _srand
    
    // Initialize window
    adrp    x0, window_title@PAGE
    add     x0, x0, window_title@PAGEOFF
    mov     w1, #WINDOW_WIDTH
    mov     w2, #WINDOW_HEIGHT
    bl      _window_init
    cmp     x0, #0
    b.ne    init_error
    
    // Initialize rasterizer
    mov     w0, #WINDOW_WIDTH
    mov     w1, #WINDOW_HEIGHT
    bl      _raster_init
    cbz     x0, init_error
    
    // Initialize maze
    bl      _maze_init
    cmp     x0, #0
    b.ne    init_error
    
    // Generate first maze
    bl      _maze_generate
    bl      randomize_colors
    
    // Set player to start position
    bl      reset_player
    
    adrp    x0, msg_ready@PAGE
    add     x0, x0, msg_ready@PAGEOFF
    bl      _print_str
    bl      _print_newline

// ============================================================================
// Main game loop
// ============================================================================
game_loop:
    bl      _window_poll
    bl      _window_should_close
    cbnz    w0, quit_game
    
    bl      _keyboard_update
    
    // Check quit keys
    bl      _keyboard_get_state
    mov     x2, x0
    ldrb    w0, [x2, #KEY_ESCAPE]
    cbnz    w0, quit_game
    ldrb    w0, [x2, #KEY_Q]
    cbnz    w0, quit_game
    
    // Check R for regenerate
    mov     w0, #KEY_R
    bl      _keyboard_just_pressed
    cbz     w0, no_regen
    bl      _maze_generate
    bl      randomize_colors
    bl      reset_player
    adrp    x0, msg_regen@PAGE
    add     x0, x0, msg_regen@PAGEOFF
    bl      _print_str
    bl      _print_newline
no_regen:
    
    // Handle player movement
    bl      handle_movement
    
    // Check win condition
    bl      check_win
    
    // ========== Render ==========
    bl      render_game
    
    // Blit to screen
    bl      _raster_get_buffer
    mov     x19, x0
    adrp    x0, _fb_pitch@PAGE
    add     x0, x0, _fb_pitch@PAGEOFF
    ldr     w3, [x0]
    mov     x0, x19
    mov     w1, #WINDOW_WIDTH
    mov     w2, #WINDOW_HEIGHT
    bl      _window_blit
    
    // Frame delay
    mov     w0, #16
    bl      _timing_sleep_ms
    
    b       game_loop

init_error:
    adrp    x0, msg_error@PAGE
    add     x0, x0, msg_error@PAGEOFF
    bl      _print_str
    bl      _print_newline
    mov     w0, #1
    b       cleanup

quit_game:
    adrp    x0, msg_quit@PAGE
    add     x0, x0, msg_quit@PAGEOFF
    bl      _print_str
    bl      _print_newline
    mov     w0, #0

cleanup:
    stp     x19, x20, [sp, #-16]!
    mov     w19, w0
    bl      _maze_free
    bl      _raster_free
    bl      _window_quit
    mov     w0, w19
    ldp     x19, x20, [sp], #16
    
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// reset_player - Reset player to start position
// ============================================================================
.align 4
reset_player:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get start position
    adrp    x0, _maze_start_x@PAGE
    add     x0, x0, _maze_start_x@PAGEOFF
    ldr     w1, [x0]
    adrp    x0, _maze_start_y@PAGE
    add     x0, x0, _maze_start_y@PAGEOFF
    ldr     w2, [x0]
    
    // Set player tile position
    adrp    x0, player_tile_x@PAGE
    add     x0, x0, player_tile_x@PAGEOFF
    str     w1, [x0]
    adrp    x0, player_tile_y@PAGE
    add     x0, x0, player_tile_y@PAGEOFF
    str     w2, [x0]
    
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// handle_movement - Move player if valid (with cooldown for controlled speed)
// ============================================================================
.align 4
handle_movement:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    // Check cooldown - decrement and skip if not zero
    adrp    x0, move_cooldown@PAGE
    add     x0, x0, move_cooldown@PAGEOFF
    ldr     w1, [x0]
    cbz     w1, cooldown_ready
    sub     w1, w1, #1
    str     w1, [x0]
    b       movement_skip
    
cooldown_ready:
    // Load current position
    adrp    x19, player_tile_x@PAGE
    add     x19, x19, player_tile_x@PAGEOFF
    ldr     w21, [x19]
    adrp    x20, player_tile_y@PAGE
    add     x20, x20, player_tile_y@PAGEOFF
    ldr     w22, [x20]
    
    // Get key state
    bl      _keyboard_get_state
    mov     x23, x0
    
    // Check Left (held)
    ldrb    w0, [x23, #KEY_LEFT]
    ldrb    w1, [x23, #KEY_A]
    orr     w0, w0, w1
    cbz     w0, check_move_right
    sub     w0, w21, #1
    mov     w1, w22
    bl      _maze_get_tile
    cmp     w0, #1                   // TILE_WALL
    b.eq    check_move_right
    sub     w21, w21, #1
    b       did_move
    
check_move_right:
    ldrb    w0, [x23, #KEY_RIGHT]
    ldrb    w1, [x23, #KEY_D]
    orr     w0, w0, w1
    cbz     w0, check_move_up
    add     w0, w21, #1
    mov     w1, w22
    bl      _maze_get_tile
    cmp     w0, #1
    b.eq    check_move_up
    add     w21, w21, #1
    b       did_move
    
check_move_up:
    ldrb    w0, [x23, #KEY_UP]
    ldrb    w1, [x23, #KEY_W]
    orr     w0, w0, w1
    cbz     w0, check_move_down
    mov     w0, w21
    sub     w1, w22, #1
    bl      _maze_get_tile
    cmp     w0, #1
    b.eq    check_move_down
    sub     w22, w22, #1
    b       did_move
    
check_move_down:
    ldrb    w0, [x23, #KEY_DOWN]
    ldrb    w1, [x23, #KEY_S]
    orr     w0, w0, w1
    cbz     w0, movement_skip
    mov     w0, w21
    add     w1, w22, #1
    bl      _maze_get_tile
    cmp     w0, #1
    b.eq    movement_skip
    add     w22, w22, #1
    
did_move:
    // Store new position
    str     w21, [x19]
    str     w22, [x20]
    
    // Reset cooldown (4 frames between moves)
    adrp    x0, move_cooldown@PAGE
    add     x0, x0, move_cooldown@PAGEOFF
    mov     w1, #4
    str     w1, [x0]
    
movement_skip:
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// check_win - Check if player reached the end
// ============================================================================
.align 4
check_win:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Get player position
    adrp    x0, player_tile_x@PAGE
    add     x0, x0, player_tile_x@PAGEOFF
    ldr     w1, [x0]
    adrp    x0, player_tile_y@PAGE
    add     x0, x0, player_tile_y@PAGEOFF
    ldr     w2, [x0]
    
    // Get end position
    adrp    x0, _maze_end_x@PAGE
    add     x0, x0, _maze_end_x@PAGEOFF
    ldr     w3, [x0]
    adrp    x0, _maze_end_y@PAGE
    add     x0, x0, _maze_end_y@PAGEOFF
    ldr     w4, [x0]
    
    // Compare
    cmp     w1, w3
    b.ne    not_win
    cmp     w2, w4
    b.ne    not_win
    
    // Win! Print message and regenerate
    adrp    x0, msg_win@PAGE
    add     x0, x0, msg_win@PAGEOFF
    bl      _print_str
    bl      _print_newline
    bl      _maze_generate
    bl      randomize_colors
    bl      reset_player
    
not_win:
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// render_game - Render maze and player
// ============================================================================
.align 4
render_game:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    
    // Clear screen with random background color
    adrp    x0, bg_r@PAGE
    add     x0, x0, bg_r@PAGEOFF
    ldrb    w0, [x0]
    adrp    x1, bg_g@PAGE
    add     x1, x1, bg_g@PAGEOFF
    ldrb    w1, [x1]
    adrp    x2, bg_b@PAGE
    add     x2, x2, bg_b@PAGEOFF
    ldrb    w2, [x2]
    mov     w3, #255
    bl      _raster_set_color
    bl      _raster_clear
    
    // Get maze data
    bl      _maze_get_data
    mov     x23, x0
    
    // Render maze tiles
    mov     w20, #0                  // y tile
render_y_loop:
    adrp    x0, _maze_height@PAGE
    add     x0, x0, _maze_height@PAGEOFF
    ldr     w0, [x0]
    cmp     w20, w0
    b.ge    render_maze_done
    
    mov     w21, #0                  // x tile
render_x_loop:
    adrp    x0, _maze_width@PAGE
    add     x0, x0, _maze_width@PAGEOFF
    ldr     w0, [x0]
    cmp     w21, w0
    b.ge    render_y_next
    
    // Get tile value
    adrp    x0, _maze_width@PAGE
    add     x0, x0, _maze_width@PAGEOFF
    ldr     w0, [x0]
    mul     w22, w20, w0
    add     w22, w22, w21
    ldrb    w24, [x23, x22]
    
    // Set color based on tile type
    cmp     w24, #1                  // Wall
    b.eq    set_wall_color
    cmp     w24, #2                  // Start
    b.eq    set_start_color
    cmp     w24, #3                  // End
    b.eq    set_end_color
    b       render_x_next           // Empty - don't draw
    
set_wall_color:
    adrp    x0, wall_r@PAGE
    add     x0, x0, wall_r@PAGEOFF
    ldrb    w0, [x0]
    adrp    x1, wall_g@PAGE
    add     x1, x1, wall_g@PAGEOFF
    ldrb    w1, [x1]
    adrp    x2, wall_b@PAGE
    add     x2, x2, wall_b@PAGEOFF
    ldrb    w2, [x2]
    mov     w3, #255
    bl      _raster_set_color
    b       draw_tile
    
set_start_color:
    mov     w0, #50
    mov     w1, #150
    mov     w2, #50
    mov     w3, #255
    bl      _raster_set_color
    b       draw_tile
    
set_end_color:
    mov     w0, #200
    mov     w1, #50
    mov     w2, #50
    mov     w3, #255
    bl      _raster_set_color
    
draw_tile:
    // Calculate pixel position
    mov     w0, w21
    lsl     w0, w0, #4               // x * 16
    mov     w1, w20
    lsl     w1, w1, #4               // y * 16
    mov     w2, #TILE_SIZE
    mov     w3, #TILE_SIZE
    bl      _raster_rect
    
render_x_next:
    add     w21, w21, #1
    b       render_x_loop
    
render_y_next:
    add     w20, w20, #1
    b       render_y_loop

render_maze_done:
    // Render player
    adrp    x0, player_tile_x@PAGE
    add     x0, x0, player_tile_x@PAGEOFF
    ldr     w19, [x0]
    adrp    x0, player_tile_y@PAGE
    add     x0, x0, player_tile_y@PAGEOFF
    ldr     w20, [x0]
    
    // Calculate pixel position (centered in tile)
    lsl     w19, w19, #4             // tile_x * 16
    add     w19, w19, #PLAYER_OFFSET // + 4 to center
    lsl     w20, w20, #4             // tile_y * 16
    add     w20, w20, #PLAYER_OFFSET
    
    // Draw body (cyan square)
    mov     w0, #0
    mov     w1, #220
    mov     w2, #200
    mov     w3, #255
    bl      _raster_set_color
    
    mov     w0, w19
    add     w1, w20, #4              // Body below head
    mov     w2, #PLAYER_SIZE
    mov     w3, #PLAYER_SIZE
    bl      _raster_rect
    
    // Draw head (coral circle)
    mov     w0, #255
    mov     w1, #100
    mov     w2, #100
    mov     w3, #255
    bl      _raster_set_color
    
    add     w0, w19, #4              // Center x
    add     w1, w20, #2              // Head y
    mov     w2, #4                   // radius
    bl      _raster_circle_filled
    
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// randomize_colors - Pick random themed colors for bg and walls
// ============================================================================
// 8 distinct themes. Colors stored as RGB for _raster_set_color.
// DEBUG: Using very distinct colors to verify RGB channels work.
// ============================================================================
.align 4
randomize_colors:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    
    // Pick random theme 0-7
    bl      _rand
    and     w19, w0, #7
    
    // Simple if-else chain (clearer than jump table)
    cmp     w19, #0
    b.eq    theme_0
    cmp     w19, #1
    b.eq    theme_1
    cmp     w19, #2
    b.eq    theme_2
    cmp     w19, #3
    b.eq    theme_3
    cmp     w19, #4
    b.eq    theme_4
    cmp     w19, #5
    b.eq    theme_5
    cmp     w19, #6
    b.eq    theme_6
    b       theme_7

theme_0:
    // RED theme - dark red bg, bright red walls
    mov     w20, #40                 // bg R (high)
    mov     w21, #10                 // bg G (low)
    mov     w22, #10                 // bg B (low)
    mov     w0, #200                 // wall R (very high)
    mov     w1, #50                  // wall G
    mov     w2, #50                  // wall B
    b       store_colors

theme_1:
    // GREEN theme - dark green bg, bright green walls
    mov     w20, #10                 // bg R (low)
    mov     w21, #40                 // bg G (high)
    mov     w22, #10                 // bg B (low)
    mov     w0, #50                  // wall R
    mov     w1, #200                 // wall G (very high)
    mov     w2, #50                  // wall B
    b       store_colors

theme_2:
    // BLUE theme - dark blue bg, bright blue walls
    mov     w20, #10                 // bg R (low)
    mov     w21, #10                 // bg G (low)
    mov     w22, #40                 // bg B (high)
    mov     w0, #50                  // wall R
    mov     w1, #50                  // wall G
    mov     w2, #200                 // wall B (very high)
    b       store_colors

theme_3:
    // YELLOW theme - dark olive bg, bright yellow walls
    mov     w20, #35                 // bg R
    mov     w21, #35                 // bg G
    mov     w22, #10                 // bg B (low)
    mov     w0, #200                 // wall R (high)
    mov     w1, #200                 // wall G (high)
    mov     w2, #40                  // wall B (low)
    b       store_colors

theme_4:
    // CYAN theme - dark teal bg, bright cyan walls
    mov     w20, #10                 // bg R (low)
    mov     w21, #35                 // bg G
    mov     w22, #35                 // bg B
    mov     w0, #40                  // wall R (low)
    mov     w1, #200                 // wall G (high)
    mov     w2, #200                 // wall B (high)
    b       store_colors

theme_5:
    // MAGENTA theme - dark purple bg, bright magenta walls
    mov     w20, #35                 // bg R
    mov     w21, #10                 // bg G (low)
    mov     w22, #35                 // bg B
    mov     w0, #200                 // wall R (high)
    mov     w1, #40                  // wall G (low)
    mov     w2, #200                 // wall B (high)
    b       store_colors

theme_6:
    // ORANGE theme - dark brown bg, bright orange walls
    mov     w20, #40                 // bg R
    mov     w21, #25                 // bg G
    mov     w22, #10                 // bg B (low)
    mov     w0, #220                 // wall R (very high)
    mov     w1, #120                 // wall G (medium)
    mov     w2, #30                  // wall B (low)
    b       store_colors

theme_7:
    // GRAY theme - dark gray bg, light gray walls
    mov     w20, #25                 // bg R
    mov     w21, #25                 // bg G
    mov     w22, #25                 // bg B
    mov     w0, #150                 // wall R
    mov     w1, #150                 // wall G
    mov     w2, #150                 // wall B

store_colors:
    // Store background colors
    adrp    x3, bg_r@PAGE
    add     x3, x3, bg_r@PAGEOFF
    strb    w20, [x3]
    adrp    x3, bg_g@PAGE
    add     x3, x3, bg_g@PAGEOFF
    strb    w21, [x3]
    adrp    x3, bg_b@PAGE
    add     x3, x3, bg_b@PAGEOFF
    strb    w22, [x3]
    
    // Store wall colors
    adrp    x3, wall_r@PAGE
    add     x3, x3, wall_r@PAGEOFF
    strb    w0, [x3]
    adrp    x3, wall_g@PAGE
    add     x3, x3, wall_g@PAGEOFF
    strb    w1, [x3]
    adrp    x3, wall_b@PAGE
    add     x3, x3, wall_b@PAGEOFF
    strb    w2, [x3]
    
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ============================================================================
// Data
// ============================================================================
.data
.align 4
player_tile_x:  .word 1
player_tile_y:  .word 1
move_cooldown:  .word 0

// Random colors (set each maze generation)
bg_r:           .byte 15
bg_g:           .byte 15
bg_b:           .byte 25
wall_r:         .byte 60
wall_g:         .byte 60
wall_b:         .byte 80

window_title:   .asciz "ASM Maze Game"
msg_init:       .asciz "[INFO] Starting maze game..."
msg_ready:      .asciz "[INFO] Arrows/WASD: move, R: new maze, ESC: quit"
msg_error:      .asciz "[ERROR] Failed to initialize!"
msg_quit:       .asciz "[INFO] Thanks for playing!"
msg_regen:      .asciz "[INFO] New maze generated!"
msg_win:        .asciz "[INFO] You WIN! Generating new maze..."
