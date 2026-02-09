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
#include "websocket_client.h"
#include "ultrasonic.h"
#include "ota_server.h"

#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_wifi.h"

#define LIGHT_PIN 2
#define HORN_PIN 3
#define BAT_ADC_CHAN ADC_CHANNEL_0 // GPIO 1 on S3

static adc_oneshot_unit_handle_t adc1_handle;

void init_hardware_ctrl() {
    // Light
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << LIGHT_PIN) | (1ULL << HORN_PIN);
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    gpio_config(&io_conf);
    
    gpio_set_level(LIGHT_PIN, 0);
    gpio_set_level(HORN_PIN, 0);

    // ADC
    adc_oneshot_unit_init_cfg_t init_config1 = {
        .unit_id = ADC_UNIT_1,
    };
    adc_oneshot_new_unit(&init_config1, &adc1_handle);

    adc_oneshot_chan_cfg_t config = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,
        .atten = ADC_ATTEN_DB_12, // 11/12dB for full range
    };
    adc_oneshot_config_channel(adc1_handle, BAT_ADC_CHAN, &config);
}

void set_light(int val) {
    gpio_set_level(LIGHT_PIN, val ? 1 : 0);
    ESP_LOGI("CTRL", "Light: %d", val);
}

void set_horn(int val) {
    gpio_set_level(HORN_PIN, val ? 1 : 0);
    ESP_LOGI("CTRL", "Horn: %d", val);
}

float get_battery_voltage() {
    int adc_raw;
    if (adc_oneshot_read(adc1_handle, BAT_ADC_CHAN, &adc_raw) == ESP_OK) {
        // Simple conversion: 3.3V ref, 12-bit (4095)
        // Voltage Divider Factor: Assuming 1:3 ratio (12V -> 3V) -> x4
        // Adjust this factor based on real hardware resistors!
        return (adc_raw * 3.3f / 4095.0f) * 4.0f;
    }
    return 0.0f;
}

int get_wifi_rssi() {
    wifi_ap_record_t ap_info;
    if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
        return ap_info.rssi;
    }
    return -100;
}

static const char *TAG = "RoboCar-A";

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
    init_hardware_ctrl();
    
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

    // Start WebSocket Client (Push Mode) if STA is connected
    char device_id[32];
    wifi_get_device_id(device_id, sizeof(device_id));
    
    // Load relay server from NVS (default to placeholder if not set)
    char ws_uri[128];
    snprintf(ws_uri, sizeof(ws_uri), "ws://192.168.1.10:8081/ws?role=device&deviceId=%s", device_id);
    websocket_client_init(ws_uri);

    ESP_LOGI(TAG, "RoboCar-A Ready! Connect to WS on port 81");
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
        float v_car = get_battery_voltage();
        int rssi = get_wifi_rssi();
        
        char json_buf[128];
        snprintf(json_buf, sizeof(json_buf), 
                 "{\"type\":\"status\",\"dist\":%.1f,\"v_car\":%.2f,\"rssi\":%d}", 
                 distance, v_car, rssi);
        websocket_server_broadcast(json_buf);
        websocket_client_send(json_buf);
        
        // Heartbeat
        vTaskDelay(pdMS_TO_TICKS(500)); // Update every 500ms
    }
}
