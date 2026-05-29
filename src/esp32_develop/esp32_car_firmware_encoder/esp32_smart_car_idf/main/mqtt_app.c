#include "mqtt_app.h"
#include "mqtt_client.h"
#include "esp_log.h"
#include "cJSON.h"
#include "car_commands.h"
#include "config_storage.h"
#include <string.h>

static const char *TAG = "MQTT_APP";
static esp_mqtt_client_handle_t client = NULL;

static void log_error_if_nonzero(const char *message, int error_code)
{
    if (error_code != 0) {
        ESP_LOGE(TAG, "Last error %s: 0x%x", message, error_code);
    }
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "Event dispatched from event loop base=%s, event_id=%" PRIi32 "", base, event_id);
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        // 订阅控制指令主题
        esp_mqtt_client_subscribe(client, "robocar/control", 0);
        break;
    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
        break;

    case MQTT_EVENT_SUBSCRIBED:
        ESP_LOGI(TAG, "MQTT_EVENT_SUBSCRIBED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_UNSUBSCRIBED:
        ESP_LOGI(TAG, "MQTT_EVENT_UNSUBSCRIBED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "MQTT_EVENT_PUBLISHED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_DATA:
        ESP_LOGI(TAG, "MQTT_EVENT_DATA");
        // 解析下发的 JSON 控制指令
        if (event->topic_len > 0 && strncmp(event->topic, "robocar/control", event->topic_len) == 0) {
            char *payload = malloc(event->data_len + 1);
            if (payload) {
                memcpy(payload, event->data, event->data_len);
                payload[event->data_len] = '\0';
                ESP_LOGI(TAG, "Received payload: %s", payload);
                char response_buf[512] = {0};
                handle_car_command(payload, response_buf, sizeof(response_buf));
                if (response_buf[0] != '\0') {
                    mqtt_app_send_status(response_buf);
                }
                free(payload);
            }
        }
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
        if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
            log_error_if_nonzero("reported from esp-tls", event->error_handle->esp_tls_last_esp_err);
            log_error_if_nonzero("reported from tls stack", event->error_handle->esp_tls_stack_err);
            log_error_if_nonzero("captured as transport's socket errno",  event->error_handle->esp_transport_sock_errno);
            ESP_LOGI(TAG, "Last errno string (%s)", strerror(event->error_handle->esp_transport_sock_errno));
        }
        break;
    default:
        ESP_LOGI(TAG, "Other event id:%d", event->event_id);
        break;
    }
}

esp_err_t mqtt_app_start(void)
{
    car_config_t cfg = {0};
    char broker_uri[MAX_CONFIG_LEN + 10] = "mqtt://192.168.1.110"; // fallback default

    if (load_car_config(&cfg) == ESP_OK && strlen(cfg.relay_url) > 0) {
        snprintf(broker_uri, sizeof(broker_uri), "mqtt://%s", cfg.relay_url);
        ESP_LOGI(TAG, "Using broker from NVS: %s", broker_uri);
    } else {
        ESP_LOGW(TAG, "No broker config in NVS, using default: %s", broker_uri);
    }

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = broker_uri,
        .credentials.username = "robocar",
        .credentials.authentication.password = "smart2026",
    };

    client = esp_mqtt_client_init(&mqtt_cfg);
    if (client == NULL) {
        return ESP_FAIL;
    }
    esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(client);
    return ESP_OK;
}

void mqtt_app_send_status(const char *json_status)
{
    if (client != NULL) {
        esp_mqtt_client_publish(client, "robocar/status", json_status, 0, 0, 0);
    }
}
