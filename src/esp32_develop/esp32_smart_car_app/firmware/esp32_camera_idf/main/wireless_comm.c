#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_now.h"
#include "esp_wifi.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "cJSON.h"
#include "wireless_comm.h"
#include "wifi_app.h"

static const char *TAG = "wireless_comm";
static uint8_t broadcast_mac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// Extern from main.c
extern void set_led_intensity(int intensity);

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

static int64_t last_sync_time = 0;

static void handle_json_cmd(cJSON *root) {
    cJSON *cmd = cJSON_GetObjectItem(root, "cmd");
    if (!cmd) return;

    if (strcmp(cmd->valuestring, "wifi_sync") == 0) {
        cJSON *ssid = cJSON_GetObjectItem(root, "ssid");
        cJSON *pass = cJSON_GetObjectItem(root, "pass");
        if (ssid && pass) {
            wifi_config_t current_conf = {0};
            if (esp_wifi_get_config(WIFI_IF_STA, &current_conf) == ESP_OK) {
                if (strncmp((char*)current_conf.sta.ssid, ssid->valuestring, 32) == 0 &&
                    strncmp((char*)current_conf.sta.password, pass->valuestring, 64) == 0) {
                    
                    // Already have these credentials, but update sync time to prevent hopping
                    last_sync_time = esp_timer_get_time();
                    return;
                }
            }

            ESP_LOGI(TAG, "Wireless WiFi Sync Received! SSID: %s", ssid->valuestring);
            last_sync_time = esp_timer_get_time(); // Record sync time
            wifi_update_credentials(ssid->valuestring, pass->valuestring);
        }
    } else if (strcmp(cmd->valuestring, "cam_ctrl") == 0) {
        cJSON *sub = cJSON_GetObjectItem(root, "sub");
        cJSON *val = cJSON_GetObjectItem(root, "val");
        if (sub && val) {
            if (strcmp(sub->valuestring, "flash") == 0) {
                set_led_intensity(val->valueint);
            }
        }
    } else if (strcmp(cmd->valuestring, "ping") == 0) {
        ESP_LOGI(TAG, "PING received via Wireless, sending PONG");
        cJSON *resp = cJSON_CreateObject();
        cJSON_AddStringToObject(resp, "res", "pong");
        send_json(resp);
        cJSON_Delete(resp);
    }
}

static void on_data_recv(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    char *buf = malloc(len + 1);
    if (!buf) return;
    memcpy(buf, data, len);
    buf[len] = '\0';
    
    ESP_LOGI(TAG, "Wireless RX: %s", buf);
    cJSON *root = cJSON_Parse(buf);
    if (root) {
        handle_json_cmd(root);
        cJSON_Delete(root);
    }
    free(buf);
}

static void channel_hopping_task(void *pvParameters) {
    uint8_t channel = 1;
    while (1) {
        // 1. Check if we recently received a sync (within last 60 seconds)
        // If so, stay on the current channel and do NOTHING.
        int64_t now = esp_timer_get_time();
        if (last_sync_time > 0 && (now - last_sync_time) < 60000000ULL) {
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }

        // 2. Check if WiFi is actually connected
        EventBits_t bits = xEventGroupGetBits(s_wifi_event_group);
        if (bits & WIFI_CONNECTED_BIT) {
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }

        // 3. If we are here, we are not connected and haven't heard from S3 recently.
        // Try next channel.
        esp_wifi_disconnect(); 
        esp_err_t err = esp_wifi_set_channel(channel, WIFI_SECOND_CHAN_NONE);
        if (err == ESP_OK) {
            ESP_LOGI(TAG, "No sync heard. Hopping to channel %d...", channel);
            channel = (channel % 13) + 1;
        }
        
        vTaskDelay(pdMS_TO_TICKS(3000)); 
    }
}

static void ip_report_task(void *pvParameters) {
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(5000)); // Report every 5 seconds
        
        EventBits_t bits = xEventGroupGetBits(s_wifi_event_group);
        if (bits & WIFI_CONNECTED_BIT) {
            esp_netif_ip_info_t ip_info;
            esp_netif_t *netif = esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
            if (netif && esp_netif_get_ip_info(netif, &ip_info) == ESP_OK) {
                char ip_str[16];
                esp_ip4addr_ntoa(&ip_info.ip, ip_str, sizeof(ip_str));
                
                cJSON *root = cJSON_CreateObject();
                cJSON_AddStringToObject(root, "res", "ip_info");
                cJSON_AddStringToObject(root, "ip", ip_str);
                char *out = cJSON_PrintUnformatted(root);
                if (out) {
                    wireless_comm_send_response(out);
                    free(out);
                }
                cJSON_Delete(root);
            }
        }
    }
}

void wireless_comm_init(void) {
    esp_err_t ret = esp_now_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "ESP-NOW init failed: %s", esp_err_to_name(ret));
        return;
    }

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
    
    // Start channel hopping task to find the S3's channel
    xTaskCreate(channel_hopping_task, "channel_hop", 2048, NULL, 5, NULL);
    
    // Start IP reporting task
    xTaskCreate(ip_report_task, "ip_report", 3072, NULL, 5, NULL);
    
    ESP_LOGI(TAG, "ESP-NOW Wireless Comm Initialized (CAM Side)");
}

void wireless_comm_send_response(const char* json_str) {
    esp_err_t ret = esp_now_send(broadcast_mac, (uint8_t *)json_str, strlen(json_str));
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Wireless response failed: %s", esp_err_to_name(ret));
    }
}
