#include <string.h>
#include <stdlib.h>
#include "esp_log.h"
#include "cJSON.h"
#include "motor_driver.h"
#include "pca9685.h"
#include "system_ctrl.h"
#include "wifi_app.h"
#include "ota_server.h"
#include "wireless_comm.h"
#include "nvs_flash.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_mac.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "car_commands.h"
#include "config_storage.h"
#include "websocket_client.h"

static const char *TAG = "car_commands";

extern int g_car_mode;

esp_err_t handle_car_command(const char *json_data, char *response_buffer, size_t response_len) {
    if (response_buffer && response_len > 0) {
        response_buffer[0] = '\0';
    }

    cJSON *root = cJSON_Parse(json_data);
    if (!root) {
        ESP_LOGE(TAG, "JSON Parse Error");
        return ESP_FAIL;
    }

    cJSON *cmd = cJSON_GetObjectItem(root, "cmd");
    if (!cmd || !cJSON_IsString(cmd)) {
        ESP_LOGW(TAG, "No 'cmd' field in JSON or not a string");
        cJSON_Delete(root);
        return ESP_FAIL;
    }

    const char *cmd_str = cmd->valuestring;
    esp_err_t ret = ESP_OK;

    if (strcmp(cmd_str, "ping") == 0) {
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"pong\"}");
    } else if (strcmp(cmd_str, "status") == 0) {
        // Get Camera IP
        const char *cam_ip = wireless_comm_get_cam_ip();

        // Get WiFi SSID (STA or AP)
        char ssid_str[33] = "Unknown";
        wifi_config_t wifi_cfg;
        memset(&wifi_cfg, 0, sizeof(wifi_cfg));
        
        wifi_mode_t mode;
        if (esp_wifi_get_mode(&mode) == ESP_OK) {
            if (mode == WIFI_MODE_STA || mode == WIFI_MODE_APSTA) {
                // Try to get active STA info first (actual connection)
                wifi_ap_record_t ap_info;
                if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
                    strncpy(ssid_str, (char*)ap_info.ssid, sizeof(ssid_str) - 1);
                    ssid_str[sizeof(ssid_str) - 1] = '\0';
                } else if (esp_wifi_get_config(WIFI_IF_STA, &wifi_cfg) == ESP_OK && strlen((char*)wifi_cfg.sta.ssid) > 0) {
                    // Fallback to saved STA config if not currently connected but configured
                    strncpy(ssid_str, (char*)wifi_cfg.sta.ssid, sizeof(ssid_str) - 1);
                    ssid_str[sizeof(ssid_str) - 1] = '\0';
                }
            }
            
            // If still unknown and we have AP mode, get AP SSID
            if (strcmp(ssid_str, "Unknown") == 0 && (mode == WIFI_MODE_AP || mode == WIFI_MODE_APSTA)) {
                if (esp_wifi_get_config(WIFI_IF_AP, &wifi_cfg) == ESP_OK) {
                    if (wifi_cfg.ap.ssid_len > 0) {
                        int len = wifi_cfg.ap.ssid_len > 32 ? 32 : wifi_cfg.ap.ssid_len;
                        memcpy(ssid_str, wifi_cfg.ap.ssid, len);
                        ssid_str[len] = '\0';
                    } else {
                        strncpy(ssid_str, (char*)wifi_cfg.ap.ssid, sizeof(ssid_str) - 1);
                        ssid_str[sizeof(ssid_str) - 1] = '\0';
                    }
                }
            }
        }

        // Get MAC address
        uint8_t mac[6];
        char mac_str[18];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X",
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

        // Get Uptime (seconds)
        int64_t uptime_s = esp_timer_get_time() / 1000000;
        char uptime_buf[32];
        snprintf(uptime_buf, sizeof(uptime_buf), "%lld", uptime_s);

        // Build JSON response using cJSON for safety
        cJSON *res = cJSON_CreateObject();
        if (res) {
            cJSON_AddStringToObject(res, "res", "ok");
            cJSON_AddStringToObject(res, "type", "status");
            cJSON_AddStringToObject(res, "cam_ip", cam_ip);
            cJSON_AddStringToObject(res, "camIP", cam_ip);
            cJSON_AddStringToObject(res, "mode", g_car_mode == 1 ? "AUTO" : "MANUAL");
            cJSON_AddNumberToObject(res, "bat", get_battery_voltage());
            cJSON_AddNumberToObject(res, "rssi", get_wifi_rssi());
            cJSON_AddStringToObject(res, "mac", mac_str);
            cJSON_AddStringToObject(res, "uptime", uptime_buf);
            cJSON_AddStringToObject(res, "ssid", ssid_str);

            char *json_str = cJSON_PrintUnformatted(res);
            if (json_str) {
                if (response_buffer) {
                    strncpy(response_buffer, json_str, response_len - 1);
                    response_buffer[response_len - 1] = '\0';
                }
                free(json_str);
            }
            cJSON_Delete(res);
        }
    } else if (strcmp(cmd_str, "info") == 0) {
        // Get MAC address
        uint8_t mac[6];
        char mac_str[18];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X",
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

        // Get Uptime
        int64_t uptime_s = esp_timer_get_time() / 1000000;
        char uptime_buf[32];
        snprintf(uptime_buf, sizeof(uptime_buf), "%lld", uptime_s);

        // Build JSON response
        cJSON *res = cJSON_CreateObject();
        if (res) {
            cJSON_AddStringToObject(res, "res", "ok");
            cJSON_AddStringToObject(res, "type", "info");
            cJSON_AddStringToObject(res, "mac", mac_str);
            cJSON_AddStringToObject(res, "uptime", uptime_buf);
            cJSON_AddStringToObject(res, "version", "1.2.0");
            cJSON_AddStringToObject(res, "model", "RoboCar-A");

            char *json_str = cJSON_PrintUnformatted(res);
            if (json_str) {
                if (response_buffer) {
                    strncpy(response_buffer, json_str, response_len - 1);
                    response_buffer[response_len - 1] = '\0';
                }
                free(json_str);
            }
            cJSON_Delete(res);
        }
    } else if (strcmp(cmd_str, "set_cam_ip") == 0) {
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val && cJSON_IsString(j_val)) {
            wireless_comm_save_cam_ip(j_val->valuestring);
            if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"cam_ip_saved\"}");
        }
    } else if (strcmp(cmd_str, "mode") == 0) {
        cJSON *j_mode = cJSON_GetObjectItem(root, "value");
        if (j_mode && cJSON_IsString(j_mode)) {
            if (strcmp(j_mode->valuestring, "AUTO") == 0) g_car_mode = 1;
            else g_car_mode = 0;
            ESP_LOGI(TAG, "Mode changed to: %s", g_car_mode == 1 ? "AUTO" : "MANUAL");
        }
    } else if (strcmp(cmd_str, "move") == 0) {
        // PRD: Manual override - any move command switches to MANUAL mode
        if (g_car_mode != 0) {
            g_car_mode = 0;
            ESP_LOGW(TAG, "Manual Override: Switching to MANUAL mode");
        }
        float vx = 0, vy = 0, vw = 0;
        cJSON *j_vx = cJSON_GetObjectItem(root, "vx");
        cJSON *j_vy = cJSON_GetObjectItem(root, "vy");
        cJSON *j_vw = cJSON_GetObjectItem(root, "vw");
        if (j_vx) vx = j_vx->valuedouble;
        if (j_vy) vy = j_vy->valuedouble;
        if (j_vw) vw = j_vw->valuedouble;
        
        ESP_LOGI(TAG, "CMD: move vx=%.2f vy=%.2f vw=%.2f", vx, vy, vw);
        move_car(vx, vy, vw);
    } else if (strcmp(cmd_str, "servo") == 0) {
        int channel = 0;
        float angle = 0;
        cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
        cJSON *j_angle = cJSON_GetObjectItem(root, "angle");
        if (j_channel) channel = j_channel->valueint;
        if (j_angle) angle = j_angle->valuedouble;
        
        pca9685_set_servo_angle(channel, angle);
    } else if (strcmp(cmd_str, "servo_step") == 0) {
        int channel = 0;
        float step = 0;
        cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
        cJSON *j_step = cJSON_GetObjectItem(root, "step");
        if (j_channel) channel = j_channel->valueint;
        if (j_step) step = j_step->valuedouble;
        
        float speed_angle = (step > 0) ? 95.0 : 85.0; 
        int duration_ms = abs((int)step) * 20; 
        
        pca9685_set_servo_angle(channel, speed_angle);
        vTaskDelay(pdMS_TO_TICKS(duration_ms));
        pca9685_stop_servo(channel); 
    } else if (strcmp(cmd_str, "servo_stop") == 0) {
        int channel = 0;
        cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
        if (j_channel) channel = j_channel->valueint;
        pca9685_stop_servo(channel);
    } else if (strcmp(cmd_str, "motor_test") == 0) {
        int id = 0;
        int speed = 0;
        cJSON *j_id = cJSON_GetObjectItem(root, "id");
        cJSON *j_speed = cJSON_GetObjectItem(root, "speed");
        if (j_id) id = j_id->valueint;
        if (j_speed) speed = j_speed->valueint;

        ESP_LOGI(TAG, "CMD: motor_test id=%d speed=%d", id, speed);
        motor_set_speed(id, speed);
    } else if (strcmp(cmd_str, "light") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "val");
        if (j_val) val = j_val->valueint;
        set_light(val);
    } else if (strcmp(cmd_str, "horn") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "val");
        if (j_val) val = j_val->valueint;
        set_horn(val);
    } else if (strcmp(cmd_str, "cam_flash") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "val");
        if (j_val) val = j_val->valueint;
        wireless_comm_send_cam_ctrl("flash", val);
    } else if (strcmp(cmd_str, "ping_cam") == 0) {
        ESP_LOGI(TAG, "Command: Pinging CAM via Wireless...");
        wireless_comm_send_ping();
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"ping_sent\"}");
    } else if (strcmp(cmd_str, "reset") == 0 || strcmp(cmd_str, "RESET") == 0) {
        ESP_LOGW(TAG, "Command: Resetting WiFi credentials...");
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"resetting\",\"type\":\"status_reset\"}");
        // Note: Resetting wifi and restarting might need a delayed task to allow response to send
        // For now we just call it.
        wifi_reset_credentials();
    } else if (strcmp(cmd_str, "restart") == 0 || strcmp(cmd_str, "RESTART") == 0 || strcmp(cmd_str, "reboot") == 0) {
        ESP_LOGW(TAG, "Command: Restarting...");
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"restarting\",\"type\":\"status_reset\"}");
        esp_restart();
    } else if (strcmp(cmd_str, "set_relay") == 0) {
        cJSON *j_url = cJSON_GetObjectItem(root, "url");
        cJSON *j_id = cJSON_GetObjectItem(root, "id");
        if (j_url && cJSON_IsString(j_url) && j_id && cJSON_IsString(j_id)) {
            car_config_t cfg;
            strncpy(cfg.relay_url, j_url->valuestring, sizeof(cfg.relay_url) - 1);
            strncpy(cfg.device_id, j_id->valuestring, sizeof(cfg.device_id) - 1);
            
            if (save_car_config(&cfg) == ESP_OK) {
                ESP_LOGI(TAG, "Relay config saved: %s, ID: %s", cfg.relay_url, cfg.device_id);
                if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"Config saved, restarting WS...\"}");
                
                // Restart WebSocket client with new config
                websocket_client_stop();
                char full_url[320];
                snprintf(full_url, sizeof(full_url), "wss://%s/ws?role=device&deviceId=%s", cfg.relay_url, cfg.device_id);
                websocket_client_start(full_url);
            } else {
                if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"error\",\"msg\":\"Save failed\"}");
            }
        }
    } else if (strcmp(cmd_str, "speed") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) val = j_val->valueint;
        ESP_LOGI(TAG, "CMD: speed set to %d", val);
        motor_set_max_speed(val * 10); 
    } else if (strcmp(cmd_str, "resolution") == 0) {
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val && cJSON_IsString(j_val)) {
            ESP_LOGI(TAG, "CMD: resolution set to %s", j_val->valuestring);
            wireless_comm_send_cam_ctrl("resolution", j_val->valuestring);
        }
    } else if (strcmp(cmd_str, "track") == 0) {
        cJSON *j_target = cJSON_GetObjectItem(root, "target");
        if (j_target && cJSON_IsString(j_target)) {
            ESP_LOGI(TAG, "CMD: tracking target set to %s", j_target->valuestring);
            // logic to set AI tracking target
            g_car_mode = 1; // Auto mode for tracking
        }
    } else if (strcmp(cmd_str, "pid_set") == 0) {
        float kp = 0, ki = 0, kd = 0;
        cJSON *j_kp = cJSON_GetObjectItem(root, "kp");
        cJSON *j_ki = cJSON_GetObjectItem(root, "ki");
        cJSON *j_kd = cJSON_GetObjectItem(root, "kd");
        if (j_kp) kp = j_kp->valuedouble;
        if (j_ki) ki = j_ki->valuedouble;
        if (j_kd) kd = j_kd->valuedouble;
        motor_set_pid_params(kp, ki, kd);
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"pid_updated\"}");
    } else if (strcmp(cmd_str, "steering") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) val = j_val->valueint;
        ESP_LOGI(TAG, "CMD: steering sensitivity set to %d", val);
        // Map 0-100 to 0.5-1.5 factor
        float factor = 0.5f + (val / 100.0f);
        motor_set_steering_factor(factor);
    } else if (strcmp(cmd_str, "deadzone") == 0) {
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) {
            motor_set_deadzone(j_val->valuedouble);
            ESP_LOGI(TAG, "CMD: deadzone set to %.2f", j_val->valuedouble);
        }
    } else if (strcmp(cmd_str, "lpf") == 0) {
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) {
            motor_set_lpf_alpha(j_val->valuedouble);
            ESP_LOGI(TAG, "CMD: lpf alpha set to %.2f", j_val->valuedouble);
        }

    } else if (strcmp(cmd_str, "factory_reset") == 0) {
        ESP_LOGW(TAG, "Command: Factory Resetting...");
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"factory_resetting\",\"type\":\"status_reset\"}");
        nvs_flash_erase();
        esp_restart();
    } else if (strcmp(cmd_str, "ota_start") == 0) {
        cJSON *url = cJSON_GetObjectItem(root, "url");
        if (url && cJSON_IsString(url)) {
            ESP_LOGI(TAG, "OTA requested: %s", url->valuestring);
            if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"OTA update started\"}");
            ota_start_from_url(url->valuestring);
        }
    } else if (strcmp(cmd_str, "system_info") == 0) {
        multi_heap_info_t heap_info;
        heap_caps_get_info(&heap_info, MALLOC_CAP_8BIT);
        if (response_buffer) {
            snprintf(response_buffer, response_len, 
                "{\"res\":\"ok\",\"type\":\"system_info\",\"version\":\"1.2.0\",\"free_heap\":%u,\"min_free\":%u}",
                (unsigned int)heap_info.total_free_bytes,
                (unsigned int)heap_info.minimum_free_bytes);
        }
    } else if (strcmp(cmd_str, "wifi_config") == 0) {
        cJSON *ssid = cJSON_GetObjectItem(root, "ssid");
        cJSON *pass = cJSON_GetObjectItem(root, "password");
        cJSON *test = cJSON_GetObjectItem(root, "test"); // Optional flag to test before saving

        if (ssid && cJSON_IsString(ssid) && pass && cJSON_IsString(pass)) {
            ESP_LOGI(TAG, "Command: WiFi Config received. SSID: %s", ssid->valuestring);
            
            bool test_passed = true;
            if (test && cJSON_IsTrue(test)) {
                if (wifi_test_connection(ssid->valuestring, pass->valuestring) != ESP_OK) {
                    test_passed = false;
                    if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"error\",\"msg\":\"wifi_test_failed\",\"type\":\"wifi_status\"}");
                }
            }

            if (test_passed) {
                if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"credentials_saved_restarting\",\"type\":\"status_reset\"}");
                wifi_save_credentials(ssid->valuestring, pass->valuestring);
            }
        } else {
            if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"error\",\"msg\":\"missing_ssid_or_password\"}");
        }
    } else if (strcmp(cmd_str, "scan_wifi") == 0) {
        ESP_LOGI(TAG, "Command: Scanning WiFi...");
        uint16_t number = 10;
        wifi_ap_record_t *ap_info = malloc(sizeof(wifi_ap_record_t) * number);
        if (ap_info == NULL) {
            if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"error\",\"msg\":\"out_of_memory\"}");
        } else {
            uint16_t ap_count = 0;
            esp_wifi_scan_start(NULL, true);
            esp_wifi_scan_get_ap_records(&number, ap_info);
            esp_wifi_scan_get_ap_num(&ap_count);

            cJSON *scan_root = cJSON_CreateObject();
            if (scan_root) {
                cJSON_AddStringToObject(scan_root, "res", "ok");
                cJSON_AddStringToObject(scan_root, "type", "scan_results");
                cJSON *networks = cJSON_AddArrayToObject(scan_root, "networks");

                if (networks) {
                    for (int i = 0; i < number; i++) {
                        if (strlen((char *)ap_info[i].ssid) == 0) continue;
                        cJSON *net = cJSON_CreateObject();
                        if (net) {
                            cJSON_AddStringToObject(net, "ssid", (char *)ap_info[i].ssid);
                            cJSON_AddNumberToObject(net, "rssi", ap_info[i].rssi);
                            cJSON_AddNumberToObject(net, "secure", ap_info[i].authmode != WIFI_AUTH_OPEN);
                            cJSON_AddItemToArray(networks, net);
                        }
                    }
                }
                
                char *json_str = cJSON_PrintUnformatted(scan_root);
                if (json_str) {
                    if (response_buffer) {
                        strncpy(response_buffer, json_str, response_len - 1);
                        response_buffer[response_len - 1] = '\0';
                    }
                    free(json_str);
                }
                cJSON_Delete(scan_root);
            }
            free(ap_info);
        }
    } else {
        ESP_LOGW(TAG, "Unknown command: %s", cmd_str);
        ret = ESP_ERR_NOT_FOUND;
    }

    cJSON_Delete(root);
    return ret;
}
