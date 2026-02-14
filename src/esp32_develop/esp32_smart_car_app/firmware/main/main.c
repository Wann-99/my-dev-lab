#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "config.h"
#include "motor_driver.h"
#include "servo_driver.h"
#include "sensor_driver.h"
#include "wifi_server.h"

static const char *TAG = "MAIN";

// Global State
static char current_mode[16] = "manual";
static float target_vx = 0;
static float target_vy = 0;
static float target_vw = 0;

void handle_command(cJSON *root) {
    cJSON *cmd_item = cJSON_GetObjectItem(root, "cmd");
    if (!cmd_item) return;
    
    const char *cmd = cmd_item->valuestring;
    
    if (strcmp(cmd, "mode") == 0) {
        cJSON *val = cJSON_GetObjectItem(root, "value");
        if (val) {
            strncpy(current_mode, val->valuestring, sizeof(current_mode)-1);
            ESP_LOGI(TAG, "Mode changed to: %s", current_mode);
            motor_stop();
            target_vx = 0; target_vy = 0; target_vw = 0;
        }
    }
    else if (strcmp(cmd, "speed") == 0) {
        cJSON *val = cJSON_GetObjectItem(root, "value");
        if (val) {
            motor_set_max_speed((uint8_t)val->valueint);
        }
    }
    else if (strcmp(cmd, "servo") == 0) {
        int id = cJSON_GetObjectItem(root, "id")->valueint;
        int angle = cJSON_GetObjectItem(root, "angle")->valueint;
        servo_set_angle(id, angle);
    }
    else if (strcmp(cmd, "move") == 0) {
        if (strcmp(current_mode, "manual") == 0) {
            target_vx = (float)cJSON_GetObjectItem(root, "vx")->valuedouble;
            target_vy = (float)cJSON_GetObjectItem(root, "vy")->valuedouble;
            target_vw = (float)cJSON_GetObjectItem(root, "vw")->valuedouble;
            
            motor_set_speed(target_vx, target_vy, target_vw);
        }
    }
}

void app_main(void) {
    ESP_LOGI(TAG, "Starting ESP32 Smart Car Firmware (IDF)");
    
    // Initialize Drivers
    motor_init();
    servo_init();
    sensor_init();
    wifi_server_init();
    
    // Set callback
    wifi_server_set_callback(handle_command);
    
    // Initial State
    servo_set_angle(0, 90);
    servo_set_angle(1, 90);

    // Main Loop
    while (1) {
        float dist = sensor_get_distance();
        wifi_server_send_status(dist, current_mode);
        
        // Auto Mode Logic
        if (strcmp(current_mode, "auto") == 0) {
            if (dist > 0 && dist < 30.0) {
                // Obstacle Detected
                motor_set_speed(0, 0, 0.6); // Rotate
                sensor_set_horn(true);
            } else {
                // Clear
                motor_set_speed(0.4, 0, 0); // Forward
                sensor_set_horn(false);
            }
        }
        
        vTaskDelay(500 / portTICK_PERIOD_MS); // 500ms loop
    }
}
