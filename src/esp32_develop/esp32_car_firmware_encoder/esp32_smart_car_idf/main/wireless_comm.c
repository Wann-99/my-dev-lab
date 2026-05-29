#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_now.h"
#include "esp_wifi.h"
#include "esp_log.h"
#include "cJSON.h"
#include "wireless_comm.h"
#include "websocket_server.h"
#include "nvs.h"
#include "nvs_flash.h"

static const char *TAG = "wireless_comm";
static uint8_t broadcast_mac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static char s_cam_ip[16] = "0.0.0.0";

void wireless_comm_save_cam_ip(const char* ip) {
    nvs_handle_t handle;
    if (nvs_open("storage", NVS_READWRITE, &handle) == ESP_OK) {
        nvs_set_str(handle, "cam_ip", ip);
        nvs_commit(handle);
        nvs_close(handle);
        strncpy(s_cam_ip, ip, sizeof(s_cam_ip) - 1);
        ESP_LOGI(TAG, "CAM IP Saved to NVS: %s", s_cam_ip);
    }
}

void wireless_comm_load_cam_ip(void) {
    nvs_handle_t handle;
    if (nvs_open("storage", NVS_READONLY, &handle) == ESP_OK) {
        size_t size = sizeof(s_cam_ip);
        if (nvs_get_str(handle, "cam_ip", s_cam_ip, &size) != ESP_OK) {
            strcpy(s_cam_ip, "0.0.0.0");
        }
        nvs_close(handle);
        ESP_LOGI(TAG, "CAM IP Loaded from NVS: %s", s_cam_ip);
    }
}

const char* wireless_comm_get_cam_ip(void) {
    return s_cam_ip;
}

static void on_data_sent(const uint8_t *mac_addr, esp_now_send_status_t status) {
    ESP_LOGD(TAG, "Data sent status: %s", status == ESP_NOW_SEND_SUCCESS ? "Success" : "Fail");
}

static void on_data_recv(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    char *buf = malloc(len + 1);
    if (!buf) return;
    memcpy(buf, data, len);
    buf[len] = '\0';
    
    ESP_LOGI(TAG, "Wireless RX: %s", buf);
    cJSON *root = cJSON_Parse(buf);
    if (root) {
        cJSON *res = cJSON_GetObjectItem(root, "res");
        if (res && cJSON_IsString(res)) {
            if (strcmp(res->valuestring, "pong") == 0) {
                ESP_LOGI(TAG, "CAM Response: PONG! Wireless link is OK.");
            } else if (strcmp(res->valuestring, "ip_info") == 0) {
                cJSON *ip = cJSON_GetObjectItem(root, "ip");
                if (ip && cJSON_IsString(ip)) {
                    if (strcmp(s_cam_ip, ip->valuestring) != 0) {
                        // Use the new save function
                        wireless_comm_save_cam_ip(ip->valuestring);
                        
                        // Push to App via WebSocket
                        char push_msg[128];
                        snprintf(push_msg, sizeof(push_msg), 
                            "{\"type\":\"status\",\"cam_ip\":\"%s\",\"camIP\":\"%s\",\"msg\":\"cam_online\"}", 
                            s_cam_ip, s_cam_ip);
                        websocket_server_broadcast(push_msg);
                    }
                }
            } else {
                ESP_LOGI(TAG, "CAM Response: %s", res->valuestring);
            }
        }
        cJSON_Delete(root);
    }
    free(buf);
}

static void wireless_sync_task(void *pvParameters) {
    while (1) {
        // Send sync every 2 seconds indefinitely for high reliability
        vTaskDelay(pdMS_TO_TICKS(2000));
        
        wifi_config_t conf;
        if (esp_wifi_get_config(WIFI_IF_STA, &conf) == ESP_OK && strlen((char*)conf.sta.ssid) > 0) {
            wireless_comm_send_wifi_sync((const char*)conf.sta.ssid, (const char*)conf.sta.password);
        }
    }
}

void wireless_comm_init(void) {
    esp_err_t ret = esp_now_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "ESP-NOW init failed: %s", esp_err_to_name(ret));
        return;
    }

    esp_now_register_send_cb(on_data_sent);
    esp_now_register_recv_cb(on_data_recv);

    // Add broadcast peer explicitly for STA interface
    esp_now_peer_info_t peer_info = {};
    memcpy(peer_info.peer_addr, broadcast_mac, 6);
    peer_info.channel = 0; 
    peer_info.ifidx = WIFI_IF_STA; // Explicitly use STA interface
    peer_info.encrypt = false;
    if (esp_now_add_peer(&peer_info) != ESP_OK) {
        ESP_LOGE(TAG, "Failed to add broadcast peer");
    }
    
    // Start background sync task
    xTaskCreate(wireless_sync_task, "wireless_sync", 3072, NULL, 5, NULL);
    
    // Load last known CAM IP from NVS
    wireless_comm_load_cam_ip();
    
    ESP_LOGI(TAG, "ESP-NOW Wireless Comm Initialized");
}

static void send_json(cJSON *root) {
    char *out = cJSON_PrintUnformatted(root);
    if (out) {
        esp_err_t ret = esp_now_send(broadcast_mac, (uint8_t *)out, strlen(out));
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "Wireless send failed: %s", esp_err_to_name(ret));
        }
        free(out);
    }
}

void wireless_comm_send_wifi_sync(const char* ssid, const char* password) {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "cmd", "wifi_sync");
    cJSON_AddStringToObject(root, "ssid", ssid);
    cJSON_AddStringToObject(root, "pass", password);
    
    ESP_LOGI(TAG, "Sending WiFi Sync to CAM (Wireless)...");
    send_json(root);
    cJSON_Delete(root);
}

void wireless_comm_send_cam_ctrl(const char* cmd, int value) {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "cmd", "cam_ctrl");
    cJSON_AddStringToObject(root, "sub", cmd);
    cJSON_AddNumberToObject(root, "val", value);
    
    ESP_LOGI(TAG, "Sending Cam Ctrl: %s=%d (Wireless)", cmd, value);
    send_json(root);
    cJSON_Delete(root);
}

void wireless_comm_send_ping(void) {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "cmd", "ping");
    
    ESP_LOGI(TAG, "Sending PING to CAM (Wireless)...");
    send_json(root);
    cJSON_Delete(root);
}
