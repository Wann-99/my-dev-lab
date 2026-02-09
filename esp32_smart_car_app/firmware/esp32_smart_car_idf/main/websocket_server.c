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

static const char *TAG = "websocket_server";
static httpd_handle_t g_server = NULL;

void handle_car_command(const char* payload)
{
    cJSON *root = cJSON_Parse(payload);
    if (root) {
        cJSON *cmd = cJSON_GetObjectItem(root, "cmd");
        if (cmd && cJSON_IsString(cmd)) {
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
                
                float speed_angle = (step > 0) ? 95.0 : 85.0; 
                int duration_ms = abs((int)step) * 20; 
                
                pca9685_set_servo_angle(channel, speed_angle);
                vTaskDelay(pdMS_TO_TICKS(duration_ms));
                pca9685_stop_servo(channel); 
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
            }
        }
        cJSON_Delete(root);
    } else {
         ESP_LOGE(TAG, "JSON Parse Error");
    }
}

static esp_err_t ws_handler(httpd_req_t *req)
{
    if (req->method == HTTP_GET) {
        ESP_LOGI(TAG, "Handshake done, the new connection was opened");
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
        
        ESP_LOGI(TAG, "Got packet with message: %s", ws_pkt.payload);
        handle_car_command((const char*)ws_pkt.payload);
        free(buf);
    }
    return ESP_OK;
}

static const httpd_uri_t ws = {
        .uri        = "/", // Arduino WebSocket usually connects to root or specific path. 
        // NOTE: Arduino WebSocketsServer usually listens on port 81 and handles WS protocol directly.
        // ESP-IDF httpd listens on 80 by default. We will change port to 81 below.
        .method     = HTTP_GET,
        .handler    = ws_handler,
        .user_ctx   = NULL,
        .is_websocket = true
};

void websocket_server_init(void)
{
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 81; // Match Arduino Port

    ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
    if (httpd_start(&g_server, &config) == ESP_OK) {
        ESP_LOGI(TAG, "Registering URI handlers");
        esp_err_t ret = httpd_register_uri_handler(g_server, &ws);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "httpd_register_uri_handler failed: %s", esp_err_to_name(ret));
        }
    } else {
        ESP_LOGI(TAG, "Error starting server!");
    }
}

void websocket_server_broadcast(const char *msg)
{
    if (!g_server) return;

    size_t max_clients = 10;
    int fds[10];
    if (httpd_get_client_list(g_server, &max_clients, fds) == ESP_OK) {
        httpd_ws_frame_t ws_pkt;
        memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
        ws_pkt.type = HTTPD_WS_TYPE_TEXT;
        ws_pkt.payload = (uint8_t *)msg;
        ws_pkt.len = strlen(msg);

        for (int i = 0; i < max_clients; i++) {
            httpd_ws_send_frame_async(g_server, fds[i], &ws_pkt);
        }
    }
}
