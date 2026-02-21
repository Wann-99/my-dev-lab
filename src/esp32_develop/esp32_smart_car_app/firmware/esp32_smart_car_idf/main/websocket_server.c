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
#include "car_commands.h"
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
        
        char response[512];
        if (handle_car_command((const char*)ws_pkt.payload, response, sizeof(response)) == ESP_OK) {
            if (strlen(response) > 0) {
                ws_send_text(req, response);
            }
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
