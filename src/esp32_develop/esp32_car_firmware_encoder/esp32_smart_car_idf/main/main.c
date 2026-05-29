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
#include "config_storage.h"
#include "ultrasonic.h"
#include "ota_server.h"
#include "wireless_comm.h"
#include "mqtt_app.h"

#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_wifi.h"
#include "esp_console.h"
#include "esp_mac.h"
#include "esp_timer.h"

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

float get_battery_voltage(void) {
    int adc_raw;
    if (adc_oneshot_read(adc1_handle, BAT_ADC_CHAN, &adc_raw) == ESP_OK) {
        // Simple conversion: 3.3V ref, 12-bit (4095)
        // Voltage Divider Factor: R1=220k, R2=100k -> (220+100)/100 = 3.2
        // Adjust this factor based on real hardware resistors!
        return (adc_raw * 3.3f / 4095.0f) * 3.2f;
    }
    return 0.0f;
}

int get_wifi_rssi(void) {
    wifi_ap_record_t ap_info;
    if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
        return ap_info.rssi;
    }
    return -100;
}

static const char *TAG = "RoboCar-A";
int g_car_mode = 0; // 0: MANUAL, 1: AUTO (Obstacle Avoidance)

void serial_console_task(void *pvParameters)
{
    char line[64];
    while (1) {
        if (fgets(line, sizeof(line), stdin) != NULL) {
            // Remove newline
            line[strcspn(line, "\n")] = 0;
            line[strcspn(line, "\r")] = 0;

            if (strcmp(line, "reset") == 0) {
                ESP_LOGW(TAG, "Serial command: Resetting WiFi credentials...");
                wifi_reset_credentials();
            } else if (strcmp(line, "restart") == 0) {
                ESP_LOGW(TAG, "Serial command: Restarting...");
                esp_restart();
            } else if (strlen(line) > 0) {
                ESP_LOGI(TAG, "Unknown serial command: %s", line);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

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
    
    // Start serial console task
    xTaskCreate(serial_console_task, "serial_task", 4096, NULL, 5, NULL);
    
    // Note: I2C Pins (SDA=11, SCL=12) defined in pca9685.h
    if (pca9685_init() == ESP_OK) {
        ESP_LOGI(TAG, "PCA9685 Initialized");
    } else {
        ESP_LOGE(TAG, "PCA9685 Init Failed - Check I2C Pins");
    }

    // 3. Network Init
    wifi_init_manager();
    wireless_comm_init();
    
    // Give some time for WiFi to stabilize before starting the server
    vTaskDelay(pdMS_TO_TICKS(1000));
    
    httpd_handle_t server = websocket_server_init(); // Start on Port 80
    if (server) {
        register_ota_handlers(server); // Register OTA on the same Port 80
        ESP_LOGI(TAG, "WebSocket server and OTA handlers registered.");
    }

    // --- RELAY SERVER CLIENT ---
    // Try to load saved config from NVS
    car_config_t cfg;
    if (load_car_config(&cfg) == ESP_OK) {
        ESP_LOGI(TAG, "Loaded saved relay config: %s, ID: %s", cfg.relay_url, cfg.device_id);
        char full_url[320];
        snprintf(full_url, sizeof(full_url), "wss://%s/ws?role=device&deviceId=%s", cfg.relay_url, cfg.device_id);
        websocket_client_start(full_url);
    } else {
        ESP_LOGW(TAG, "No saved relay config. Use local App to configure via 'set_relay' command.");
        // Fallback or default for first-time use
        // const char* default_url = "wss://your-default-server.com/ws?role=device&deviceId=car_01";
        // websocket_client_start(default_url);
    }
    // ---------------------------

    // Start mDNS service AFTER the server is ready
    start_mdns_service();

    // Start MQTT Client
    mqtt_app_start();

    ESP_LOGI(TAG, "RoboCar-A Ready! Connect to WS/HTTP on port 80");
    ESP_LOGI(TAG, "You can use serial command 'reset' to erase WiFi configuration.");

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
        
        // --- AUTO MODE LOGIC (Obstacle Avoidance) ---
        if (g_car_mode == 1) {
            if (distance > 0 && distance < 30.0f) {
                // Obstacle detected within 30cm: Stop and Rotate
                move_car(0, 0, 0.5f); 
                set_horn(1);
            } else {
                // Path clear: Move forward slowly
                move_car(0.4f, 0, 0);
                set_horn(0);
            }
        }
        // --------------------------------------------

        // Broadcast to App (Local and Remote)
        float v_car = get_battery_voltage();
        int rssi = get_wifi_rssi();
        const char* cam_ip = wireless_comm_get_cam_ip();
        
        uint8_t mac[6];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        char mac_str[18];
        snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X", 
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        
        int64_t uptime_s = esp_timer_get_time() / 1000000;
        int days = uptime_s / 86400;
        int hours = (uptime_s % 86400) / 3600;
        char uptime_buf[32];
        if (days > 0) {
            snprintf(uptime_buf, sizeof(uptime_buf), "%d天 %d小时", days, hours);
        } else {
            snprintf(uptime_buf, sizeof(uptime_buf), "%d小时", hours);
        }

        // Get WiFi SSID
        char ssid_str[33] = "Unknown";
        wifi_config_t wifi_cfg;
        if (esp_wifi_get_config(WIFI_IF_STA, &wifi_cfg) == ESP_OK) {
            strncpy(ssid_str, (char*)wifi_cfg.sta.ssid, sizeof(ssid_str) - 1);
        }
        
        char json_buf[320]; 
        snprintf(json_buf, sizeof(json_buf), 
                 "{\"type\":\"status\",\"dist\":%.1f,\"v_car\":%.2f,\"rssi\":%d,\"mode\":\"%s\",\"cam_ip\":\"%s\",\"mac\":\"%s\",\"uptime\":\"%s\",\"ssid\":\"%s\"}", 
                 distance, v_car, rssi, (g_car_mode == 1 ? "AUTO" : "MANUAL"), cam_ip, mac_str, uptime_buf, ssid_str);
        
        // Send to local clients
        websocket_server_broadcast(json_buf);
        
        // Send to relay server
        if (websocket_client_is_connected()) {
            websocket_client_send(json_buf);
        }
        
        // Send via MQTT
        mqtt_app_send_status(json_buf);
        
        // Heartbeat
        vTaskDelay(pdMS_TO_TICKS(500)); // Update every 500ms
    }
}
