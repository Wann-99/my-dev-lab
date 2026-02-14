#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_system.h>
#include <esp_err.h>
#include <nvs_flash.h>
#include <sys/param.h>
#include <string.h>
#include <stdlib.h>
#include "esp_netif.h"
#include "esp_http_server.h"
#include "cJSON.h"
#include "motor_driver.h"
#include "pca9685.h"
#include "system_ctrl.h"
#include "wifi_app.h"
#include "ota_server.h"

static const char *TAG = "websocket_server";
static httpd_handle_t g_server = NULL;

// Forward declarations
void websocket_server_broadcast(const char *msg);

// Helper to send text message to specific client
static esp_err_t ws_send_text(httpd_req_t *req, const char *text) {
    httpd_ws_frame_t ws_pkt;
    memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
    ws_pkt.payload = (uint8_t*)text;
    ws_pkt.len = strlen(text);
    ws_pkt.type = HTTPD_WS_TYPE_TEXT;
    return httpd_ws_send_frame(req, &ws_pkt);
}

static void handle_ws_disconnect(int fd) {
    ESP_LOGW(TAG, "WebSocket client disconnected (FD: %d). Resetting car state...", fd);
    // 1. 硬件状态复位
    move_car(0, 0, 0);
    for (int i = 0; i < 16; i++) {
        pca9685_stop_servo(i);
    }
    set_light(0);
    set_horn(0);

    // 2. 向所有剩余客户端广播状态重置消息，让 App 界面恢复初始
    // 这样如果一个 App 退出，其他在线的 App 也能同步更新 UI
    const char* reset_ui_msg = "{\"type\":\"status_reset\",\"reason\":\"client_disconnected\"}";
    websocket_server_broadcast(reset_ui_msg);
}

// User context for WebSocket sessions
typedef struct {
    int fd;
} ws_session_t;

// Free user context when session ends
static void ws_close_handler(void* arg) {
    if (arg) {
        ws_session_t *session = (ws_session_t*)arg;
        handle_ws_disconnect(session->fd);
        free(session);
    }
}

static esp_err_t ws_handler(httpd_req_t *req)
{
    if (req->method == HTTP_GET) {
        ESP_LOGI(TAG, "Handshake done, the new connection was opened");
        
        // Setup session context to track disconnection
        ws_session_t *session = calloc(1, sizeof(ws_session_t));
        if (session) {
            session->fd = httpd_req_to_sockfd(req);
            req->sess_ctx = session;
            req->free_ctx = ws_close_handler;
        }

        // Send a welcome message to confirm connection to the App
        const char* welcome_msg = "{\"type\":\"welcome\",\"status\":\"connected\"}";
        httpd_ws_frame_t ws_pkt = {
            .final = true,
            .fragmented = false,
            .type = HTTPD_WS_TYPE_TEXT,
            .payload = (uint8_t*)welcome_msg,
            .len = strlen(welcome_msg)
        };
        httpd_ws_send_frame(req, &ws_pkt);
        
        return ESP_OK;
    }

    httpd_ws_frame_t ws_pkt;
    uint8_t *buf = NULL;
    memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
    ws_pkt.type = HTTPD_WS_TYPE_TEXT;
    
    // Set max_len = 0 to get the frame len
    esp_err_t ret = httpd_ws_recv_frame(req, &ws_pkt, 0);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "httpd_ws_recv_frame failed to get frame len with %d", ret);
        return ret;
    }

    if (ws_pkt.len) {
        buf = calloc(1, ws_pkt.len + 1);
        if (buf == NULL) {
            ESP_LOGE(TAG, "Failed to calloc memory for buf");
            return ESP_ERR_NO_MEM;
        }
        ws_pkt.payload = buf;
        ret = httpd_ws_recv_frame(req, &ws_pkt, ws_pkt.len);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "httpd_ws_recv_frame failed with %d", ret);
            free(buf);
            return ret;
        }
        
        cJSON *root = cJSON_Parse((const char*)ws_pkt.payload);
        if (root) {
            cJSON *cmd = cJSON_GetObjectItem(root, "cmd");
            if (cmd && cJSON_IsString(cmd)) {
                // Filter out 'ping' logs to keep the console clean
                if (strcmp(cmd->valuestring, "ping") == 0) {
                    // Send pong response back to keep connection alive
                    ws_send_text(req, "{\"res\":\"pong\"}");
                } else {
                    ESP_LOGI(TAG, "Got packet with message: %s", ws_pkt.payload);
                }

                if (strcmp(cmd->valuestring, "move") == 0) {
                    float vx = 0, vy = 0, vw = 0;
                    cJSON *j_vx = cJSON_GetObjectItem(root, "vx");
                    cJSON *j_vy = cJSON_GetObjectItem(root, "vy");
                    cJSON *j_vw = cJSON_GetObjectItem(root, "vw");
                    if (j_vx) vx = j_vx->valuedouble;
                    if (j_vy) vy = j_vy->valuedouble;
                    if (j_vw) vw = j_vw->valuedouble;
                    
                    ESP_LOGI(TAG, "CMD: move vx=%.2f vy=%.2f vw=%.2f", vx, vy, vw);
                    move_car(vx, vy, vw);
                } else if (strcmp(cmd->valuestring, "servo") == 0) {
                    int channel = 0;
                    float angle = 0;
                    cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
                    cJSON *j_angle = cJSON_GetObjectItem(root, "angle");
                    if (j_channel) channel = j_channel->valueint;
                    if (j_angle) angle = j_angle->valuedouble;
                    
                    pca9685_set_servo_angle(channel, angle);
                } else if (strcmp(cmd->valuestring, "servo_step") == 0) {
                    int channel = 0;
                    float step = 0;
                    cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
                    cJSON *j_step = cJSON_GetObjectItem(root, "step");
                    if (j_channel) channel = j_channel->valueint;
                    if (j_step) step = j_step->valuedouble;
                    
                    // Logic for 360 Continuous Servo (Simulate Step)
                    // 90 is Stop. <90 is CW, >90 is CCW.
                    // We spin at a fixed speed for a duration proportional to step size.
                    
                    float speed_angle = (step > 0) ? 95.0 : 85.0; // Slow speed
                    int duration_ms = abs((int)step) * 20; // 20ms per "degree" unit
                    
                    pca9685_set_servo_angle(channel, speed_angle);
                    vTaskDelay(pdMS_TO_TICKS(duration_ms));
                    pca9685_stop_servo(channel); // Stop
                } else if (strcmp(cmd->valuestring, "servo_stop") == 0) {
                    int channel = 0;
                    cJSON *j_channel = cJSON_GetObjectItem(root, "channel");
                    if (j_channel) channel = j_channel->valueint;
                    
                    pca9685_stop_servo(channel);
                } else if (strcmp(cmd->valuestring, "motor_test") == 0) {
                    int id = 0;
                    int speed = 0;
                    cJSON *j_id = cJSON_GetObjectItem(root, "id");
                    cJSON *j_speed = cJSON_GetObjectItem(root, "speed");
                    if (j_id) id = j_id->valueint;
                    if (j_speed) speed = j_speed->valueint;

                    ESP_LOGI(TAG, "CMD: motor_test id=%d speed=%d", id, speed);
                    motor_set_speed(id, speed);
                } else if (strcmp(cmd->valuestring, "light") == 0) {
                    int val = 0;
                    cJSON *j_val = cJSON_GetObjectItem(root, "val");
                    if (j_val) val = j_val->valueint;
                    set_light(val);
                } else if (strcmp(cmd->valuestring, "horn") == 0) {
                    int val = 0;
                    cJSON *j_val = cJSON_GetObjectItem(root, "val");
                    if (j_val) val = j_val->valueint;
                    set_horn(val);
                } else if (strcmp(cmd->valuestring, "reset") == 0 || strcmp(cmd->valuestring, "RESET") == 0) {
                    ESP_LOGW(TAG, "WS command: Resetting WiFi credentials...");
                    ws_send_text(req, "{\"res\":\"ok\",\"msg\":\"resetting\",\"type\":\"status_reset\"}");
                    vTaskDelay(pdMS_TO_TICKS(500)); 
                    wifi_reset_credentials();
                } else if (strcmp(cmd->valuestring, "restart") == 0 || strcmp(cmd->valuestring, "RESTART") == 0 || strcmp(cmd->valuestring, "reboot") == 0) {
                    ESP_LOGW(TAG, "WS command: Restarting...");
                    ws_send_text(req, "{\"res\":\"ok\",\"msg\":\"restarting\",\"type\":\"status_reset\"}");
                    vTaskDelay(pdMS_TO_TICKS(500));
                    esp_restart();
                } else if (strcmp(cmd->valuestring, "speed") == 0) {
                    int val = 0;
                    cJSON *j_val = cJSON_GetObjectItem(root, "value");
                    if (j_val) val = j_val->valueint;
                    ESP_LOGI(TAG, "CMD: speed set to %d", val);
                    // Map App speed (0-255) to Driver speed (0-1023)
                    // If App sends 0-1023 directly, this still works if we adjust the mapping.
                    // car_state.dart sends (maxSpeed * 255).toInt(), so it is 0-255.
                    motor_set_max_speed(val * 4); 
                } else if (strcmp(cmd->valuestring, "factory_reset") == 0) {
                    ESP_LOGW(TAG, "WS command: Factory Resetting...");
                    // Send response first, then delay, then erase and restart
                    ws_send_text(req, "{\"res\":\"ok\",\"msg\":\"factory_resetting\",\"type\":\"status_reset\"}");
                    vTaskDelay(pdMS_TO_TICKS(1500)); // Give more time for network buffer to flush
                    
                    // Clear NVS
                    nvs_flash_erase();
                    // Optionally clear other partitions if needed, but erase_all on "wifi_config" is already done by reset
                    
                    esp_restart();
                } else if (strcmp(cmd->valuestring, "ota_start") == 0) {
                    cJSON *url = cJSON_GetObjectItem(root, "url");
                    if (url && cJSON_IsString(url)) {
                        ESP_LOGI(TAG, "OTA requested via WS: %s", url->valuestring);
                        ws_send_text(req, "{\"res\":\"ok\",\"msg\":\"OTA update started\"}");
                        ota_start_from_url(url->valuestring);
                    }
                } else if (strcmp(cmd->valuestring, "system_info") == 0) {
                    char info_buf[256];
                    multi_heap_info_t heap_info;
                    heap_caps_get_info(&heap_info, MALLOC_CAP_8BIT);
                    
                    snprintf(info_buf, sizeof(info_buf), 
                        "{\"res\":\"ok\",\"type\":\"system_info\",\"version\":\"1.1.0\",\"free_heap\":%u,\"min_free\":%u}",
                        (unsigned int)heap_info.total_free_bytes,
                        (unsigned int)heap_info.minimum_free_bytes);
                    ws_send_text(req, info_buf);
                } else if (strcmp(cmd->valuestring, "wifi_config") == 0) {
                    cJSON *ssid = cJSON_GetObjectItem(root, "ssid");
                    cJSON *pass = cJSON_GetObjectItem(root, "password");
                    if (ssid && cJSON_IsString(ssid) && pass && cJSON_IsString(pass)) {
                        ESP_LOGI(TAG, "WS command: New WiFi Config received. SSID: %s", ssid->valuestring);
                        ws_send_text(req, "{\"res\":\"ok\",\"msg\":\"credentials_saved_restarting\",\"type\":\"status_reset\"}");
                        vTaskDelay(pdMS_TO_TICKS(1000));
                        wifi_save_credentials(ssid->valuestring, pass->valuestring);
                    } else {
                        ws_send_text(req, "{\"res\":\"error\",\"msg\":\"missing_ssid_or_password\"}");
                    }
                } else if (strcmp(cmd->valuestring, "scan_wifi") == 0) {
                    ESP_LOGI(TAG, "WS command: Scanning WiFi...");
                    uint16_t number = 10;
                    wifi_ap_record_t *ap_info = malloc(sizeof(wifi_ap_record_t) * number);
                    if (ap_info == NULL) {
                        ws_send_text(req, "{\"res\":\"error\",\"msg\":\"out_of_memory\"}");
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
                                ws_send_text(req, json_str);
                                free(json_str);
                            }
                            cJSON_Delete(scan_root);
                        }
                        free(ap_info);
                    }
                }
            } else {
                ESP_LOGW(TAG, "No 'cmd' field in JSON or not a string");
            }
            cJSON_Delete(root);
        } else {
             ESP_LOGE(TAG, "JSON Parse Error");
        }

        free(buf);
    }
    return ESP_OK;
}

static const httpd_uri_t ws = {
        .uri        = "/",
        .method     = HTTP_GET,
        .handler    = ws_handler,
        .user_ctx   = NULL,
        .is_websocket = true
};

static const httpd_uri_t ws_alt = {
        .uri        = "/ws",
        .method     = HTTP_GET,
        .handler    = ws_handler,
        .user_ctx   = NULL,
        .is_websocket = true
};

httpd_handle_t websocket_server_init(void)
{
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80; // Standard Port
    config.max_open_sockets = 4; // Reduced to 4 for better compatibility
    config.lru_purge_enable = true; // Auto close old connections
    config.ctrl_port = 32768;

    ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
    if (httpd_start(&g_server, &config) == ESP_OK) {
        ESP_LOGI(TAG, "Registering WebSocket URI handlers");
        httpd_register_uri_handler(g_server, &ws);
        httpd_register_uri_handler(g_server, &ws_alt);
        ESP_LOGI(TAG, "WebSocket server started on port %d", config.server_port);
        return g_server;
    } else {
        ESP_LOGE(TAG, "Error starting server!");
        return NULL;
    }
}

void websocket_server_broadcast(const char *msg)
{
    if (!g_server) return;

    size_t max_clients = 4; // Matches config.max_open_sockets
    int fds[4];
    if (httpd_get_client_list(g_server, &max_clients, fds) == ESP_OK) {
        httpd_ws_frame_t ws_pkt;
        memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
        ws_pkt.type = HTTPD_WS_TYPE_TEXT;
        ws_pkt.payload = (uint8_t *)msg;
        ws_pkt.len = strlen(msg);

        for (int i = 0; i < max_clients; i++) {
            // Check if it's a WS session before sending
            if (httpd_ws_get_fd_info(g_server, fds[i]) == HTTPD_WS_CLIENT_WEBSOCKET) {
                esp_err_t ret = httpd_ws_send_frame_async(g_server, fds[i], &ws_pkt);
                if (ret != ESP_OK) {
                    // Log only significant errors, ignore "already closed" if possible
                    if (ret != ESP_ERR_INVALID_ARG) { // ESP_ERR_INVALID_ARG often means bad FD
                        ESP_LOGD(TAG, "Failed to send async frame to FD %d: %d", fds[i], ret);
                    }
                }
            }
        }
    }
}
