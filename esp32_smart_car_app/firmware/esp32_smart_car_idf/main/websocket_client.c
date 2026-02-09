#include <stdio.h>
#include <string.h>
#include "esp_log.h"
#include "esp_event.h"
#include "esp_websocket_client.h"
#include "cJSON.h"
#include "websocket_client.h"
#include "motor_driver.h"
#include "pca9685.h"
#include "system_ctrl.h"

static const char *TAG = "websocket_client";
static esp_websocket_client_handle_t client = NULL;
static bool is_connected = false;

// Forward declaration of command handler (reusing logic from server)
extern void handle_car_command(const char* payload);

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
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
            ESP_LOGI(TAG, "WEBSOCKET_EVENT_DATA (Text): %.*s", data->data_len, (char *)data->data_ptr);
            // Copy data to null-terminated buffer for parsing
            char *buf = malloc(data->data_len + 1);
            if (buf) {
                memcpy(buf, data->data_ptr, data->data_len);
                buf[data->data_len] = '\0';
                handle_car_command(buf);
                free(buf);
            }
        }
        break;
    case WEBSOCKET_EVENT_ERROR:
        ESP_LOGI(TAG, "WEBSOCKET_EVENT_ERROR");
        break;
    }
}

esp_err_t websocket_client_init(const char *uri)
{
    if (client != NULL) {
        return ESP_OK;
    }

    esp_websocket_client_config_t websocket_cfg = {
        .uri = uri,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 5000,
    };

    ESP_LOGI(TAG, "Connecting to %s", uri);

    client = esp_websocket_client_init(&websocket_cfg);
    esp_websocket_register_events(client, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void *)client);

    return esp_websocket_client_start(client);
}

void websocket_client_stop(void)
{
    if (client) {
        esp_websocket_client_stop(client);
        esp_websocket_client_destroy(client);
        client = NULL;
        is_connected = false;
    }
}

void websocket_client_send(const char *msg)
{
    if (client && esp_websocket_client_is_connected(client)) {
        esp_websocket_client_send_text(client, msg, strlen(msg), portMAX_DELAY);
    }
}

bool websocket_client_is_connected(void)
{
    return is_connected;
}
