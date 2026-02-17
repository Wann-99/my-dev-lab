#ifndef DISPLAY_DRIVER_H
#define DISPLAY_DRIVER_H

#include <stdint.h>

// Display Dimensions
#define DISPLAY_WIDTH  96
#define DISPLAY_HEIGHT 48

// Color definitions (Monochrome)
// Non-zero means pixel ON, 0 means pixel OFF
#define COLOR_BLACK   0x0000
#define COLOR_WHITE   0xFFFF
// Other colors mapped to white for compatibility
#define COLOR_BLUE    COLOR_WHITE
#define COLOR_RED     COLOR_WHITE
#define COLOR_GREEN   COLOR_WHITE
#define COLOR_CYAN    COLOR_WHITE
#define COLOR_MAGENTA COLOR_WHITE
#define COLOR_YELLOW  COLOR_WHITE

void display_init(void);
void display_fill(uint16_t color);
void display_draw_pixel(int x, int y, uint16_t color);
void display_draw_string(int x, int y, const char *str, int size, uint16_t color);
void display_draw_waveform(int *values, int count, int y_offset, int height, uint16_t color);
void display_update(void); // New function to flush buffer for ST7565

#endif // DISPLAY_DRIVER_H
