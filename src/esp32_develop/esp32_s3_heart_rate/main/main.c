#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "ble_hrm.h"
#include "display_driver.h"
#include "peripherals.h"

#define TAG "MAIN"

typedef enum {
    DISPLAY_MODE_DIGITAL = 0,
    DISPLAY_MODE_WAVEFORM
} display_mode_t;

#include "esp_timer.h"

static display_mode_t s_display_mode = DISPLAY_MODE_DIGITAL;
static uint16_t s_current_hr = 0;
static bool s_hr_updated = false;

// Waveform Buffer
static int s_waveform_buffer[DISPLAY_WIDTH]; // Ring buffer
static int s_waveform_head = 0; // Current write position

// Beat Simulation
static int64_t s_last_beat_time = 0;
static int s_beat_phase = -1; // -1: no beat, >=0: index in beat pattern
// Simple QRS Complex Pattern (Scaled relative to center)
// Center is 0. Up is positive.
static const int s_beat_pattern[] = {0, 2, 5, -3, -10, 20, -15, -5, 2, 0}; 
static const int s_beat_pattern_len = 10;

void hr_callback(uint16_t hr_value)
{
    ESP_LOGI(TAG, "New HR: %d", hr_value);
    s_current_hr = hr_value;
    s_hr_updated = true;
    
    // Beep and Flash LED logic remains...
    int beep_duration = 50;
    if (hr_value > 120) beep_duration = 30;
    else if (hr_value < 60) beep_duration = 80;

    // Only beep in Digital Mode here, or maybe always?
    // Let's keep it simple.
    led_set(true);
    buzzer_beep(beep_duration); 
    led_set(false);
}

void button_callback(void)
{
    if (s_display_mode == DISPLAY_MODE_DIGITAL) {
        s_display_mode = DISPLAY_MODE_WAVEFORM;
        ESP_LOGI(TAG, "Switched to Waveform Mode");
    } else {
        s_display_mode = DISPLAY_MODE_DIGITAL;
        ESP_LOGI(TAG, "Switched to Digital Mode");
    }
    // Force update
    s_hr_updated = true;
}

void display_task(void *arg)
{
    char buf[16];
    // Initialize buffer with center line (24)
    for(int i=0; i<DISPLAY_WIDTH; i++) {
        s_waveform_buffer[i] = DISPLAY_HEIGHT / 2;
    }
    
    while (1) {
        if (s_display_mode == DISPLAY_MODE_DIGITAL) {
            // Only update on change or periodically to show "WAIT"
            if (s_hr_updated || s_current_hr == 0) {
                s_hr_updated = false;
                
                display_fill(0); 
                
                if (s_current_hr == 0) {
                    display_draw_string(14, 13, "WAIT", 3, 1);
                } else {
                    snprintf(buf, sizeof(buf), "%d", s_current_hr);
                    int x_pos = (DISPLAY_WIDTH - (strlen(buf) * 18)) / 2;
                    if (x_pos < 0) x_pos = 0;
                    display_draw_string(x_pos, 14, buf, 3, 1);
                }
                display_update();
            }
            vTaskDelay(pdMS_TO_TICKS(100)); // Lower refresh rate for digital
        } else {
            // Waveform Mode - Continuous Update (e.g., 30 FPS)
            // 1. Calculate next sample
            int sample = DISPLAY_HEIGHT / 2; // Baseline
            int64_t now = esp_timer_get_time() / 1000; // ms
            
            int interval_ms = 1000;
            if (s_current_hr > 0) {
                interval_ms = 60000 / s_current_hr;
            }
            
            // Trigger beat
            if (s_beat_phase < 0) {
                if (s_current_hr > 0 && (now - s_last_beat_time > interval_ms)) {
                    s_beat_phase = 0;
                    s_last_beat_time = now;
                }
            }
            
            // Get sample from pattern
            if (s_beat_phase >= 0) {
                sample += s_beat_pattern[s_beat_phase];
                s_beat_phase++;
                if (s_beat_phase >= s_beat_pattern_len) {
                    s_beat_phase = -1; // End of beat
                }
            }
            
            // Add some noise for realism? Maybe not.
            
            // 2. Add to ring buffer
            s_waveform_buffer[s_waveform_head] = sample;
            s_waveform_head = (s_waveform_head + 1) % DISPLAY_WIDTH;
            
            // 3. Prepare linear buffer for drawing
            // We want the newest sample at the rightmost edge?
            // Or scrolling left?
            // Usually: Newest at Right. Oldest at Left.
            // s_waveform_head points to the NEXT write position (oldest in buffer effectively)
            // So: linear[0] = buffer[head], linear[last] = buffer[head-1]
            
            int linear_buf[DISPLAY_WIDTH];
            for(int i=0; i<DISPLAY_WIDTH; i++) {
                linear_buf[i] = s_waveform_buffer[(s_waveform_head + i) % DISPLAY_WIDTH];
            }
            
            // 4. Draw
            display_fill(0);
            
            // Draw small BPM indicator in corner
            if (s_current_hr > 0) {
                snprintf(buf, sizeof(buf), "%d", s_current_hr);
                display_draw_string(0, 0, buf, 1, 1);
            }
            
            // Draw Waveform
            // Pass height=DISPLAY_HEIGHT because values are already scaled to screen coordinates (0-48)
            // But display_draw_waveform does scaling: 
            // y = (HEIGHT-1) - (val * (HEIGHT-1) / height)
            // If we pass val=24, height=48 -> y = 47 - (24 * 47 / 48) = 47 - 23.5 = 23. Correct.
            display_draw_waveform(linear_buf, DISPLAY_WIDTH, 0, DISPLAY_HEIGHT, 1);
            
            display_update();
            
            vTaskDelay(pdMS_TO_TICKS(33)); // ~30 FPS
        }
    }
}

void app_main(void)
{
    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Initialize Peripherals
    peripherals_init();
    button_register_callback(button_callback);

    // Initialize Display
    display_init();
    // display_fill(COLOR_BLUE); // Removed, let display_task handle it
    
    // Test Buzzer
    ESP_LOGI(TAG, "Testing Buzzer...");
    buzzer_beep(200); // Short beep at startup
    
    // Initialize BLE
    ble_hrm_init(hr_callback);
    ble_hrm_start_scan();

    // Create Display Task
    xTaskCreate(display_task, "display_task", 4096, NULL, 5, NULL);
    
    ESP_LOGI(TAG, "System Initialized");
}
