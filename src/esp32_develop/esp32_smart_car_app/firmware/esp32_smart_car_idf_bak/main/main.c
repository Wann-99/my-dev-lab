#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_err.h"
#include "nvs_flash.h"

#include "wifi_app.h"
#include "motor_driver.h"
#include "pca9685.h"
#include "websocket_server.h"
#include "ultrasonic.h"
#include "ota_server.h"

static const char *TAG = "SmartCar";

void app_main(void)
{
    ESP_LOGI(TAG, "System Initializing...");

    // 1. NVS Init (Required for WiFi)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // 2. Hardware Init
    motor_init();
    ultrasonic_init();
    
    // Note: I2C Pins (SDA=11, SCL=12) defined in pca9685.h
    // Ensure these do not conflict with M4_IN2(8) or TRIG(9)
    if (pca9685_init() == ESP_OK) {
        ESP_LOGI(TAG, "PCA9685 Initialized");
    } else {
        ESP_LOGE(TAG, "PCA9685 Init Failed - Check I2C Pins");
    }

    // 3. Network Init
    wifi_init_manager();
    websocket_server_init(); // Port 81
    init_ota_server();       // Port 8080 (OTA)

    ESP_LOGI(TAG, "Smart Car Ready! Connect to WS on port 81");
    ESP_LOGI(TAG, "OTA Server Ready! Connect to http://<ip>:8080/update");

    // --- HARDWARE SELF TEST ---
    ESP_LOGI(TAG, "=== STARTING HARDWARE SELF TEST ===");
    
    // Test Ultrasonic (Retry 3 times)
    float test_dist = -1;
    for (int i = 0; i < 3; i++) {
        test_dist = ultrasonic_get_distance_cm();
        if (test_dist > 0) break;
        vTaskDelay(pdMS_TO_TICKS(50)); // Wait 50ms before retry
    }

    if (test_dist < 0) {
        ESP_LOGE(TAG, "[FAIL] Ultrasonic: Timeout or Not Connected (Check GPIO 9/10)");
    } else {
        ESP_LOGI(TAG, "[PASS] Ultrasonic: %.2f cm", test_dist);
    }

    // Test Servos (Calibration/Home)
    ESP_LOGI(TAG, "Calibrating Servos...");
    
    // 1. Ultrasonic (Ch 0) - Sweep Test (Left -> Right -> Center)
    ESP_LOGI(TAG, "Ultrasonic Servo Sweep...");
    pca9685_set_servo_angle(0, 45);
    vTaskDelay(pdMS_TO_TICKS(300));
    pca9685_set_servo_angle(0, 135);
    vTaskDelay(pdMS_TO_TICKS(300));
    pca9685_set_servo_angle(0, 90); // Return to Center

    // 2. Camera (Ch 1) - Quick Calibrate (Wiggle -> Stop)
    ESP_LOGI(TAG, "Camera Servo Init...");
    // Assuming 360 Continuous Servo:
    // < 90 CW, > 90 CCW, 90 Stop
    pca9685_set_servo_angle(1, 85); // Slow Move
    vTaskDelay(pdMS_TO_TICKS(200));
    pca9685_set_servo_angle(1, 95); // Slow Move Back
    vTaskDelay(pdMS_TO_TICKS(200));
    pca9685_stop_servo(1); // Force Stop (Cut Signal)

    // 3. Reserve (Ch 2)
    pca9685_stop_servo(2);

    ESP_LOGI(TAG, "=== HARDWARE SELF TEST COMPLETE ===");
    // --------------------------

    // 4. Main Loop
    while (1) {
        // Read Distance
        float distance = ultrasonic_get_distance_cm();
        
        // Log locally if valid
        if (distance > 0) {
             // ESP_LOGI(TAG, "Distance: %.2f cm", distance);
        } else {
             distance = -1.0; // Mark as error
        }

        // Broadcast to App
        char json_buf[64];
        snprintf(json_buf, sizeof(json_buf), "{\"type\":\"status\",\"dist\":%.1f}", distance);
        websocket_server_broadcast(json_buf);
        
        // Heartbeat
        vTaskDelay(pdMS_TO_TICKS(500)); // Update every 500ms
    }
}
