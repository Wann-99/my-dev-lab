#include <string.h>
#include <stdlib.h>
#include "esp_log.h"
#include "cJSON.h"
#include "motor_driver.h"
#include "pca9685.h"
#include "system_ctrl.h"
#include "wifi_app.h"
#include "ota_server.h"
#include "nvs_flash.h"
#include "esp_system.h"
#include "esp_wifi.h"
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
    } else if (strcmp(cmd_str, "strategy") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) val = j_val->valueint;
        ESP_LOGI(TAG, "CMD: strategy set to %d (0=PID, 1=SMC)", val);
        motor_set_control_strategy(val);
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"strategy_updated\",\"val\":%d}", val);
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
    } else if (strcmp(cmd_str, "smc_set") == 0) {
        float k_sw = 0, k_p = 0, boundary = 0;
        cJSON *j_k_sw = cJSON_GetObjectItem(root, "k_sw");
        cJSON *j_k_p = cJSON_GetObjectItem(root, "k_p");
        cJSON *j_boundary = cJSON_GetObjectItem(root, "boundary");
        if (j_k_sw) k_sw = j_k_sw->valuedouble;
        if (j_k_p) k_p = j_k_p->valuedouble;
        if (j_boundary) boundary = j_boundary->valuedouble;
        motor_set_smc_params(k_sw, k_p, boundary);
        if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"smc_updated\"}");
    } else if (strcmp(cmd_str, "steering") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) val = j_val->valueint;
        ESP_LOGI(TAG, "CMD: steering sensitivity set to %d", val);
        // Map 0-100 to 0.5-1.5 factor
        float factor = 0.5f + (val / 100.0f);
        motor_set_steering_factor(factor);
    } else if (strcmp(cmd_str, "accel") == 0) {
        int val = 0;
        cJSON *j_val = cJSON_GetObjectItem(root, "value");
        if (j_val) val = j_val->valueint;
        ESP_LOGI(TAG, "CMD: accel smoothness set to %d", val);
        // Map 0-100 to 10-110 ramp step (Higher = faster acceleration)
        int ramp = 10 + val;
        motor_set_ramp_step(ramp);
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
        if (ssid && cJSON_IsString(ssid) && pass && cJSON_IsString(pass)) {
            ESP_LOGI(TAG, "Command: New WiFi Config received. SSID: %s", ssid->valuestring);
            if (response_buffer) snprintf(response_buffer, response_len, "{\"res\":\"ok\",\"msg\":\"credentials_saved_restarting\",\"type\":\"status_reset\"}");
            wifi_save_credentials(ssid->valuestring, pass->valuestring);
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
