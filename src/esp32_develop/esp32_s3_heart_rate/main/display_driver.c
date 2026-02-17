#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "display_driver.h"

#define TAG "DISPLAY"

// SPI Pins
#define LCD_HOST    SPI2_HOST
#define PIN_NUM_MISO -1
#define PIN_NUM_MOSI 7   // SDA
#define PIN_NUM_CLK  6   // SCL
#define PIN_NUM_CS   5   // CS
#define PIN_NUM_DC   18  // RS/A0
#define PIN_NUM_RST  17  // RST
#define PIN_NUM_BCKL -1  // No Backlight Pin

// ST7565 Commands
#define CMD_DISPLAY_OFF   0xAE
#define CMD_DISPLAY_ON    0xAF
#define CMD_SET_DISP_START_LINE 0x40
#define CMD_SET_PAGE      0xB0
#define CMD_SET_COLUMN_UPPER 0x10
#define CMD_SET_COLUMN_LOWER 0x00
#define CMD_SET_ADC_NORMAL  0xA0
#define CMD_SET_ADC_REVERSE 0xA1
#define CMD_SET_DISP_NORMAL 0xA6
#define CMD_SET_DISP_REVERSE 0xA7
#define CMD_SET_ALLPTS_NORMAL 0xA4
#define CMD_SET_ALLPTS_ON   0xA5
#define CMD_SET_BIAS_9      0xA2
#define CMD_SET_BIAS_7      0xA3
#define CMD_RMW             0xE0
#define CMD_RMW_CLEAR       0xEE
#define CMD_INTERNAL_RESET  0xE2
#define CMD_SET_COM_NORMAL  0xC0
#define CMD_SET_COM_REVERSE 0xC8
#define CMD_SET_POWER_CONTROL 0x28
#define CMD_SET_RESISTOR_RATIO 0x20
#define CMD_SET_VOLUME_FIRST  0x81
#define CMD_SET_VOLUME_SECOND 0x00
#define CMD_SET_STATIC_OFF    0xAC
#define CMD_SET_STATIC_ON     0xAD
#define CMD_SET_STATIC_REG    0x00
#define CMD_SET_BOOSTER_FIRST 0xF8
#define CMD_SET_BOOSTER_234   0x00
#define CMD_SET_BOOSTER_5     0x01
#define CMD_SET_BOOSTER_6     0x03
#define CMD_NOP               0xE3
#define CMD_TEST              0xF0

static spi_device_handle_t spi;
#define BUFFER_SIZE (DISPLAY_WIDTH * DISPLAY_HEIGHT / 8)
static uint8_t framebuffer[BUFFER_SIZE];

// Minimal 5x7 Font (ASCII 32-127)
static const uint8_t font5x7[][5] = {
    {0x00, 0x00, 0x00, 0x00, 0x00}, // space
    {0x00, 0x00, 0x5F, 0x00, 0x00}, // !
    {0x00, 0x07, 0x00, 0x07, 0x00}, // "
    {0x14, 0x7F, 0x14, 0x7F, 0x14}, // #
    {0x24, 0x2A, 0x7F, 0x2A, 0x12}, // $
    {0x23, 0x13, 0x08, 0x64, 0x62}, // %
    {0x36, 0x49, 0x55, 0x22, 0x50}, // &
    {0x00, 0x05, 0x03, 0x00, 0x00}, // '
    {0x00, 0x1C, 0x22, 0x41, 0x00}, // (
    {0x00, 0x41, 0x22, 0x1C, 0x00}, // )
    {0x14, 0x08, 0x3E, 0x08, 0x14}, // *
    {0x08, 0x08, 0x3E, 0x08, 0x08}, // +
    {0x00, 0x50, 0x30, 0x00, 0x00}, // ,
    {0x08, 0x08, 0x08, 0x08, 0x08}, // -
    {0x00, 0x60, 0x60, 0x00, 0x00}, // .
    {0x20, 0x10, 0x08, 0x04, 0x02}, // /
    {0x3E, 0x51, 0x49, 0x45, 0x3E}, // 0
    {0x00, 0x42, 0x7F, 0x40, 0x00}, // 1
    {0x42, 0x61, 0x51, 0x49, 0x46}, // 2
    {0x21, 0x41, 0x45, 0x4B, 0x31}, // 3
    {0x18, 0x14, 0x12, 0x7F, 0x10}, // 4
    {0x27, 0x45, 0x45, 0x45, 0x39}, // 5
    {0x3C, 0x4A, 0x49, 0x49, 0x30}, // 6
    {0x01, 0x71, 0x09, 0x05, 0x03}, // 7
    {0x36, 0x49, 0x49, 0x49, 0x36}, // 8
    {0x06, 0x49, 0x49, 0x29, 0x1E}, // 9
    {0x00, 0x36, 0x36, 0x00, 0x00}, // :
    {0x00, 0x56, 0x36, 0x00, 0x00}, // ;
    {0x08, 0x14, 0x22, 0x41, 0x00}, // <
    {0x14, 0x14, 0x14, 0x14, 0x14}, // =
    {0x00, 0x41, 0x22, 0x14, 0x08}, // >
    {0x02, 0x01, 0x51, 0x09, 0x06}, // ?
    {0x32, 0x49, 0x79, 0x41, 0x3E}, // @
    {0x7E, 0x11, 0x11, 0x11, 0x7E}, // A
    {0x7F, 0x49, 0x49, 0x49, 0x36}, // B
    {0x3E, 0x41, 0x41, 0x41, 0x22}, // C
    {0x7F, 0x41, 0x41, 0x22, 0x1C}, // D
    {0x7F, 0x49, 0x49, 0x49, 0x41}, // E
    {0x7F, 0x09, 0x09, 0x09, 0x01}, // F
    {0x3E, 0x41, 0x49, 0x49, 0x7A}, // G
    {0x7F, 0x08, 0x08, 0x08, 0x7F}, // H
    {0x00, 0x41, 0x7F, 0x41, 0x00}, // I
    {0x20, 0x40, 0x41, 0x3F, 0x01}, // J
    {0x7F, 0x08, 0x14, 0x22, 0x41}, // K
    {0x7F, 0x40, 0x40, 0x40, 0x40}, // L
    {0x7F, 0x02, 0x0C, 0x02, 0x7F}, // M
    {0x7F, 0x04, 0x08, 0x10, 0x7F}, // N
    {0x3E, 0x41, 0x41, 0x41, 0x3E}, // O
    {0x7F, 0x09, 0x09, 0x09, 0x06}, // P
    {0x3E, 0x41, 0x51, 0x21, 0x5E}, // Q
    {0x7F, 0x09, 0x19, 0x29, 0x46}, // R
    {0x46, 0x49, 0x49, 0x49, 0x31}, // S
    {0x01, 0x01, 0x7F, 0x01, 0x01}, // T
    {0x3F, 0x40, 0x40, 0x40, 0x3F}, // U
    {0x1F, 0x20, 0x40, 0x20, 0x1F}, // V
    {0x3F, 0x40, 0x38, 0x40, 0x3F}, // W
    {0x63, 0x14, 0x08, 0x14, 0x63}, // X
    {0x07, 0x08, 0x70, 0x08, 0x07}, // Y
    {0x61, 0x51, 0x49, 0x45, 0x43}, // Z
};

static void lcd_spi_pre_transfer_callback(spi_transaction_t *t)
{
    int dc = (int)t->user;
    gpio_set_level(PIN_NUM_DC, dc);
}

void lcd_cmd(const uint8_t cmd)
{
    esp_err_t ret;
    spi_transaction_t t;
    memset(&t, 0, sizeof(t));
    t.length = 8;
    t.tx_buffer = &cmd;
    t.user = (void*)0; // DC=0
    ret = spi_device_polling_transmit(spi, &t);
    ESP_ERROR_CHECK(ret);
}

void lcd_data(const uint8_t *data, int len)
{
    if (len == 0) return;
    esp_err_t ret;
    spi_transaction_t t;
    memset(&t, 0, sizeof(t));
    t.length = len * 8;
    t.tx_buffer = data;
    t.user = (void*)1; // DC=1
    ret = spi_device_polling_transmit(spi, &t);
    ESP_ERROR_CHECK(ret);
}

void display_init(void)
{
    esp_err_t ret;
    
    // GPIO Init
    gpio_reset_pin(PIN_NUM_DC);
    gpio_set_direction(PIN_NUM_DC, GPIO_MODE_OUTPUT);
    gpio_reset_pin(PIN_NUM_RST);
    gpio_set_direction(PIN_NUM_RST, GPIO_MODE_OUTPUT);
    
    // Backlight (if used)
    if (PIN_NUM_BCKL != -1) {
        gpio_reset_pin(PIN_NUM_BCKL);
        gpio_set_direction(PIN_NUM_BCKL, GPIO_MODE_OUTPUT);
        gpio_set_level(PIN_NUM_BCKL, 1); // Turn on
    }

    // SPI Init
    spi_bus_config_t buscfg = {
        .miso_io_num = PIN_NUM_MISO,
        .mosi_io_num = PIN_NUM_MOSI,
        .sclk_io_num = PIN_NUM_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = 2048
    };
    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = 4000 * 1000, // 4 MHz
        .mode = 0, // SPI mode 0 (CPOL=0, CPHA=0)
        .spics_io_num = PIN_NUM_CS,
        .queue_size = 7,
        .pre_cb = lcd_spi_pre_transfer_callback,
    };
    ret = spi_bus_initialize(LCD_HOST, &buscfg, SPI_DMA_CH_AUTO);
    ESP_ERROR_CHECK(ret);
    ret = spi_bus_add_device(LCD_HOST, &devcfg, &spi);
    ESP_ERROR_CHECK(ret);

    // Reset Sequence
    gpio_set_level(PIN_NUM_RST, 0);
    vTaskDelay(200 / portTICK_PERIOD_MS); // Longer reset
    gpio_set_level(PIN_NUM_RST, 1);
    vTaskDelay(200 / portTICK_PERIOD_MS); // Longer wait after reset

    // Initialization Sequence for ST7565 (Matching U8g2 ERC12864_ALT)
    lcd_cmd(CMD_INTERNAL_RESET); // 0xE2
    vTaskDelay(50 / portTICK_PERIOD_MS);
    
    lcd_cmd(CMD_SET_BIAS_9);     // 0xA2 (1/9 Bias)
    lcd_cmd(CMD_SET_ADC_NORMAL); // 0xA0 (ADC Normal - Addr 0 -> Seg 0)
    lcd_cmd(CMD_SET_COM_REVERSE); // 0xC8 (COM Reverse - Com 63 -> 0)
    
    lcd_cmd(CMD_SET_RESISTOR_RATIO | 0x5); // 0x25
    lcd_cmd(CMD_SET_VOLUME_FIRST); // 0x81 (Electronic volume mode)
    lcd_cmd(0x20);                 // Contrast value (Set to 0x20, adjust if needed)
    
    lcd_cmd(CMD_SET_POWER_CONTROL | 0x7); // 0x2F (Power control: all on)
    vTaskDelay(50 / portTICK_PERIOD_MS);
    
    lcd_cmd(CMD_SET_DISP_NORMAL);  // 0xA6 (Normal Display)
    lcd_cmd(CMD_DISPLAY_ON);       // 0xAF (Display On)
    
    // Clear buffer (0x00)
    memset(framebuffer, 0, sizeof(framebuffer));
    display_update();
    
    // Test Pattern: Border and Cross
    // Draw horizontal and vertical lines to make it thicker
    for(int x=0; x<128; x++) {
        display_draw_pixel(x, 0, 1);
        display_draw_pixel(x, 1, 1); // Double thickness
        display_draw_pixel(x, 62, 1);
        display_draw_pixel(x, 63, 1);
    }
    for(int y=0; y<64; y++) {
        display_draw_pixel(0, y, 1);
        display_draw_pixel(1, y, 1);
        display_draw_pixel(126, y, 1);
        display_draw_pixel(127, y, 1);
    }
    // Draw Cross
    for(int x=0; x<128; x++) {
        display_draw_pixel(x, x/2, 1); 
        display_draw_pixel(x, 63 - x/2, 1); 
    }
    
    display_update();
    vTaskDelay(200 / portTICK_PERIOD_MS); // Reduced from 1000
    
    // Clear again
    memset(framebuffer, 0, sizeof(framebuffer));
    display_update();
}

void display_fill(uint16_t color)
{
    memset(framebuffer, (color ? 0xFF : 0x00), sizeof(framebuffer));
    display_update();
}

void display_update(void)
{
    for (int page = 0; page < DISPLAY_HEIGHT/8; page++) {
        // LCD9648: 96x48.
        // ADC_REVERSE (0xA1): RAM 0=Right, RAM 127=Left (or vice versa depending on wiring).
        // Observation:
        // - col_start=0  -> "Right side content" (RAM 0..95 visible on Right)
        // - col_start=32 -> "Left side content" (RAM 32..127 visible on Left)
        // Conclusion:
        // - RAM 0 is Right Edge. RAM 127 is Left Edge.
        // - The Glass uses the middle 96 pixels of the 128 controller outputs?
        // - Or simply RAM 16..111 maps to the 96 pixels?
        // - To center 96 pixels in 128 RAM space: Offset = (128 - 96) / 2 = 16.
        int col_start = 0; 
        
        lcd_cmd(CMD_SET_PAGE | page);
        lcd_cmd(CMD_SET_COLUMN_UPPER | (((col_start) >> 4) & 0x0F));
        lcd_cmd(CMD_SET_COLUMN_LOWER | ((col_start) & 0x0F)); 
        
        lcd_data(&framebuffer[page * DISPLAY_WIDTH], DISPLAY_WIDTH);
    }
}

void display_draw_pixel(int x, int y, uint16_t color)
{
    if (x < 0 || x >= DISPLAY_WIDTH || y < 0 || y >= DISPLAY_HEIGHT) return;
    
    // ADC_NORMAL: SEG 0 (Right) -> SEG 131 (Left).
    // If we write to Column 0, it goes to SEG 0 (Right).
    // If we want x=0 to be Left, we need to map x=0 to Column 95 (or 127).
    
    // Let's use Software Flip again to map x=0 to Max Column.
    // If width is 96, Max Column is 95.
    // x = 95 - x;
    
    // But wait, user said "Left side blank, Right side content" with ADC_NORMAL + Offset 0 + No Flip.
    // That means Column 0 starts at Right.
    // So to fill the Left side, we need to write to higher columns?
    // OR use ADC_REVERSE.
    
    // Let's switch BACK to ADC_REVERSE (0xA1).
    // ADC_REVERSE: SEG 131 (Left) -> SEG 0 (Right)? Or SEG 0 (Left) -> SEG 131 (Right)?
    // Usually ADC_REVERSE means SEG 0 is Left.
    // If SEG 0 is Left, then Column 0 is Left.
    // Then x=0 -> Column 0 -> Left.
    
    // So let's force ADC_REVERSE in Init, and standard mapping here.
    
    // But previous attempt with ADC_REVERSE + No Flip gave "Left side blank, Right side content".
    // That implies Column 0 is actually somewhere in the middle or Right?
    // Maybe "LCD9648" controller is 128-wide but glass uses SEG 32-127?
    // If so, Column 0-31 are off-screen (or blank).
    
    // Let's try adding an offset to the update function instead.
    
    // x = x; // Standard
    
    int page = y / 8;
    int bit = y % 8;
    int idx = page * DISPLAY_WIDTH + x;
    
    if (color) {
        framebuffer[idx] |= (1 << bit);
    } else {
        framebuffer[idx] &= ~(1 << bit);
    }
}

void display_draw_string(int x, int y, const char *str, int size, uint16_t color)
{
    // Draw Digits (size x size pixels per dot)
    int scale = size;
    
    while (*str) {
        char c = *str;
        if (c >= 32 && c <= 126) {
            int char_idx = c - 32;
            const uint8_t *bitmap = font5x7[char_idx];
            for (int col = 0; col < 5; col++) {
                uint8_t col_data = bitmap[col];
                for (int row = 0; row < 7; row++) {
                    if (col_data & (1 << row)) {
                        // Draw scaled pixel
                        for(int dx=0; dx<scale; dx++) {
                            for(int dy=0; dy<scale; dy++) {
                                display_draw_pixel(x + col*scale + dx, y + row*scale + dy, color);
                            }
                        }
                    } else {
                        // Draw background pixel (clear)
                        for(int dx=0; dx<scale; dx++) {
                            for(int dy=0; dy<scale; dy++) {
                                display_draw_pixel(x + col*scale + dx, y + row*scale + dy, !color);
                            }
                        }
                    }
                }
            }
            // Add space between characters
            for (int row = 0; row < 7*scale; row++) {
                for (int dx=0; dx<scale; dx++) {
                     display_draw_pixel(x + 5*scale + dx, y + row, !color);
                }
            }
            x += (5 + 1) * scale;
        }
        str++;
    }
}

void display_draw_waveform(int *values, int count, int y_offset, int height, uint16_t color)
{
    // Ensure we don't draw out of bounds
    if (count > DISPLAY_WIDTH) count = DISPLAY_WIDTH;

    int prev_y = -1;
    for (int i = 0; i < count; i++) {
        int val = values[i];
        
        // Scale val (0-height) to display height (0-DISPLAY_HEIGHT-1)
        int y = (DISPLAY_HEIGHT - 1) - (val * (DISPLAY_HEIGHT - 1) / height);
        
        if (y < 0) y = 0;
        if (y >= DISPLAY_HEIGHT) y = DISPLAY_HEIGHT - 1;
        
        // Connect points with line (Vertical interpolation)
        if (i > 0 && prev_y != -1) {
            int y_start = prev_y;
            int y_end = y;
            
            // Draw vertical line from prev_y to y
            // We draw at x = i-1 because we are connecting (i-1, prev_y) to (i, y)
            // But for simple visualization, we can just draw a vertical line at i (or i-1)
            // Let's draw vertical line at current X if difference is large
            
            int step = (y_start < y_end) ? 1 : -1;
            int curr = y_start;
            while (curr != y_end) {
                curr += step;
                display_draw_pixel(i, curr, color); // Draw vertical segment at current x
                // Make it thicker (2px width)
                display_draw_pixel(i-1, curr, color); 
            }
        }
        
        display_draw_pixel(i, y, color);
        // Make it thicker (2px width)
        if (i > 0) display_draw_pixel(i-1, y, color);
        
        prev_y = y;
    }
}
