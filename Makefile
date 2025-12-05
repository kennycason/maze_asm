# ============================================================================
# Makefile for Maze ASM
# ============================================================================
# Native macOS ARM64 assembly maze game
#
# Targets:
#   make          - Build the game
#   make clean    - Remove build artifacts
#   make run      - Build and run the game
# ============================================================================

# Assembler/Linker
AS = as
LD = ld

# Architecture (ARM64 for Apple Silicon)
ARCH = arm64

# Flags
ASFLAGS = -arch $(ARCH)
LDFLAGS = -arch $(ARCH) \
          -syslibroot $(shell xcrun --show-sdk-path) \
          -lSystem \
          -framework Cocoa \
          -framework CoreGraphics \
          -framework AppKit \
          -framework QuartzCore

# Directories
PLATFORM_DIR = src/platform/macos
SHARED_DIR = src/shared
INC_DIR = include
BUILD_DIR = build

# Source files
PLATFORM_SRCS = $(PLATFORM_DIR)/print.s \
                $(PLATFORM_DIR)/keyboard.s \
                $(PLATFORM_DIR)/window.s \
                $(PLATFORM_DIR)/timing.s

SHARED_SRCS = $(SHARED_DIR)/raster.s $(SHARED_DIR)/maze_gen.s

MAIN_SRC = src/maze.s

# Object files
PLATFORM_OBJS = $(patsubst $(PLATFORM_DIR)/%.s,$(BUILD_DIR)/%.o,$(PLATFORM_SRCS))
SHARED_OBJS = $(patsubst $(SHARED_DIR)/%.s,$(BUILD_DIR)/%.o,$(SHARED_SRCS))
MAIN_OBJ = $(BUILD_DIR)/main.o

ALL_OBJS = $(PLATFORM_OBJS) $(SHARED_OBJS) $(MAIN_OBJ)

# Output
TARGET = $(BUILD_DIR)/maze

# ============================================================================
# Targets
# ============================================================================

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(ALL_OBJS)
	@echo "Linking $(TARGET)..."
	$(LD) $(LDFLAGS) -o $@ $^
	@echo "Build complete! Run with: $(TARGET)"

# Platform-specific objects
$(BUILD_DIR)/%.o: $(PLATFORM_DIR)/%.s | $(BUILD_DIR)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -I$(INC_DIR) -o $@ $<

# Shared objects
$(BUILD_DIR)/%.o: $(SHARED_DIR)/%.s | $(BUILD_DIR)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -I$(INC_DIR) -o $@ $<

# Main game
$(BUILD_DIR)/main.o: src/maze.s | $(BUILD_DIR)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -I$(INC_DIR) -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory."

run: all
	@echo "Running maze..."
	@$(TARGET)

# ============================================================================
# Help
# ============================================================================

help:
	@echo "Maze ASM Makefile"
	@echo ""
	@echo "Native macOS ARM64 assembly maze game"
	@echo ""
	@echo "Targets:"
	@echo "  make              - Build the game"
	@echo "  make run          - Build and run the game"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make help         - Show this help"
	@echo ""
	@echo "Controls:"
	@echo "  Arrow keys / WASD - Move through the maze"
	@echo "  R                 - Generate new maze"
	@echo "  ESC / Q           - Quit"
