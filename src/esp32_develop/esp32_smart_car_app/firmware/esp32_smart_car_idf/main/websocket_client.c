#include <stdio.h>
#include "esp_log.h"
#include "esp_websocket_client.h"
#include "esp_event.h"
#include "websocket_client.h"
#include "car_commands.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

static const char *TAG = "websocket_client";
static esp_websocket_client_handle_t client = NULL;
static bool is_connected = false;

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    esp_websocket_event_data_t *data = (esp_websocket_event_data_t *)event_data;
    switch (event_id) {
    case WEBSOCKET_EVENT_CONNECTED:
        ESP_LOGI(TAG, "WEBSOCKET_EVENT_CONNECTED");
        is_connected = true;
        break;
    case WEBSOCKET_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "WEBSOCKET_EVENT_DISCONNECTED");
        is_connected = false;
        break;
    case WEBSOCKET_EVENT_DATA:
        if (data->op_code == WS_TRANSPORT_OPCODES_TEXT) {
            // Log if not a ping/pong
            // ESP_LOGI(TAG, "WEBSOCKET_EVENT_DATA: Received=%.*s", data->data_len, (char *)data->data_ptr);
            
            // Process command
            char *buf = malloc(data->data_len + 1);
            if (buf) {
                memcpy(buf, data->data_ptr, data->data_len);
                buf[data->data_len] = '\0';
                
                char response[512];
                if (handle_car_command(buf, response, sizeof(response)) == ESP_OK) {
                    if (strlen(response) > 0) {
                        websocket_client_send(response);
                    }
                }
                free(buf);
            }
        }
        break;
    case WEBSOCKET_EVENT_ERROR:
        ESP_LOGI(TAG, "WEBSOCKET_EVENT_ERROR");
        break;
    }
}

esp_err_t websocket_client_start(const char *url) {
    if (client != NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    esp_websocket_client_config_t websocket_cfg = {
        .uri = url,
        .headers = "ngrok-skip-browser-warning: 69420\r\n", // Bypass ngrok warning page
    };

    // For wss:// connections, we might need to skip certificate verification if no CA is provided
    // In newer ESP-IDF, this is often handled by default if cert_pem is NULL, 
    // but some configurations might require explicit flags.

    ESP_LOGI(TAG, "Connecting to %s...", websocket_cfg.uri);

    client = esp_websocket_client_init(&websocket_cfg);
    esp_websocket_register_events(client, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void *)client);

    return esp_websocket_client_start(client);
}

void websocket_client_stop(void) {
    if (client == NULL) return;
    esp_websocket_client_stop(client);
    esp_websocket_client_destroy(client);
    client = NULL;
    is_connected = false;
}

esp_err_t websocket_client_send(const char *data) {
    if (client == NULL || !is_connected) {
        return ESP_FAIL;
    }
    int len = strlen(data);
    int ret = esp_websocket_client_send_text(client, data, len, portMAX_DELAY);
    return (ret > 0) ? ESP_OK : ESP_FAIL;
}

bool websocket_client_is_connected(void) {
    return is_connected;
}
