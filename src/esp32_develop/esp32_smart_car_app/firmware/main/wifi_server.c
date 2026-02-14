#include "wifi_server.h"
#include "config.h"
#include "web_page.h"
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_mac.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_http_server.h"

#if !CONFIG_HTTPD_WS_SUPPORT
#error "WebSocket support not enabled! Please run 'idf.py menuconfig' -> Component config -> HTTP Server -> Enable WebSocket support, or ensure CONFIG_HTTPD_WS_SUPPORT=y in sdkconfig"
#endif

static const char *TAG = "WIFI";
static httpd_handle_t server = NULL;
static command_callback_t cmd_callback = NULL;

// --- WiFi AP Setup ---

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                                    int32_t event_id, void* event_data) {
    if (event_id == WIFI_EVENT_AP_STACONNECTED) {
        wifi_event_ap_staconnected_t* event = (wifi_event_ap_staconnected_t*) event_data;
        ESP_LOGI(TAG, "station "MACSTR" join, AID=%d",
                 MAC2STR(event->mac), event->aid);
    } else if (event_id == WIFI_EVENT_AP_STADISCONNECTED) {
        wifi_event_ap_stadisconnected_t* event = (wifi_event_ap_stadisconnected_t*) event_data;
        ESP_LOGI(TAG, "station "MACSTR" leave, AID=%d",
                 MAC2STR(event->mac), event->aid);
    }
}

void wifi_init_softap(void) {
    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    esp_event_handler_instance_register(WIFI_EVENT,
                                        ESP_EVENT_ANY_ID,
                                        &wifi_event_handler,
                                        NULL,
                                        NULL);

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = WIFI_SSID,
            .ssid_len = strlen(WIFI_SSID),
            .channel = 1,
            .password = WIFI_PASS,
            .max_connection = 4,
            .authmode = WIFI_AUTH_WPA_WPA2_PSK,
        },
    };
    if (strlen(WIFI_PASS) == 0) {
        wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    }

    esp_wifi_set_mode(WIFI_MODE_AP);
    esp_wifi_set_config(WIFI_IF_AP, &wifi_config);
    esp_wifi_start();

    ESP_LOGI(TAG, "wifi_init_softap finished. SSID:%s password:%s channel:%d",
             WIFI_SSID, WIFI_PASS, 1);
}

// --- HTTP & WebSocket Handler ---

// Handler for GET / (Serve HTML)
static esp_err_t root_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html");
    httpd_resp_send(req, index_html, HTTPD_RESP_USE_STRLEN);
    return ESP_OK;
}

static const httpd_uri_t root = {
    .uri       = "/",
    .method    = HTTP_GET,
    .handler   = root_handler,
    .user_ctx  = NULL
};

struct async_resp_arg {
    httpd_handle_t hd;
    int fd;
    char *data;
};

// Handler for GET /ws (WebSocket)
static esp_err_t ws_handler(httpd_req_t *req) {
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
    if (ret != ESP_OK) return ret;

    if (ws_pkt.len) {
        buf = calloc(1, ws_pkt.len + 1);
        if (buf == NULL) return ESP_ERR_NO_MEM;
        
        ws_pkt.payload = buf;
        ret = httpd_ws_recv_frame(req, &ws_pkt, ws_pkt.len);
        if (ret != ESP_OK) {
            free(buf);
            return ret;
        }
        
        // Parse JSON
        if (ws_pkt.type == HTTPD_WS_TYPE_TEXT) {
            cJSON *root = cJSON_Parse((char*)ws_pkt.payload);
            if (root) {
                if (cmd_callback) {
                    cmd_callback(root);
                }
                cJSON_Delete(root);
            } else {
                ESP_LOGE(TAG, "JSON Parse Error");
            }
        }
        free(buf);
    }
    return ESP_OK;
}

static const httpd_uri_t ws = {
        .uri        = "/ws",
        .method     = HTTP_GET,
        .handler    = ws_handler,
        .user_ctx   = NULL,
        .is_websocket = true
};

static httpd_handle_t start_webserver(void) {
    httpd_handle_t server = NULL;
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = WS_PORT;
    config.max_open_sockets = 7; // Increase max sockets

    ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
    if (httpd_start(&server, &config) == ESP_OK) {
        ESP_LOGI(TAG, "Registering URI handlers");
        httpd_register_uri_handler(server, &root);
        httpd_register_uri_handler(server, &ws);
        return server;
    }

    ESP_LOGI(TAG, "Error starting server!");
    return NULL;
}

// --- Public API ---

void wifi_server_init(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    wifi_init_softap();
    server = start_webserver();
}

void wifi_server_set_callback(command_callback_t cb) {
    cmd_callback = cb;
}

static void send_async(void *arg) {
    struct async_resp_arg *resp_arg = (struct async_resp_arg *)arg;
    httpd_handle_t hd = resp_arg->hd;
    int fd = resp_arg->fd;
    char *data = resp_arg->data;
    
    httpd_ws_frame_t ws_pkt;
    memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
    ws_pkt.payload = (uint8_t*)data;
    ws_pkt.len = strlen(data);
    ws_pkt.type = HTTPD_WS_TYPE_TEXT;

    httpd_ws_send_frame_async(hd, fd, &ws_pkt);
    free(data);
    free(resp_arg);
}

void wifi_server_send_status(float dist, const char* mode) {
    if (!server) return;
    
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "type", "status");
    cJSON_AddNumberToObject(root, "dist", dist);
    cJSON_AddStringToObject(root, "mode", mode);
    char *json_str = cJSON_PrintUnformatted(root);
    
    // Broadcast to all clients
    size_t fds = 10;
    int client_fds[10];
    if (httpd_get_client_list(server, &fds, client_fds) == ESP_OK) {
        for (int i = 0; i < fds; i++) {
             // Basic check: Assume all clients are interested
             // Ideally we should check if client requested upgrade
             
             char *data_copy = strdup(json_str);
             struct async_resp_arg *arg = malloc(sizeof(struct async_resp_arg));
             if (arg) {
                arg->hd = server;
                arg->fd = client_fds[i];
                arg->data = data_copy;
                
                if (httpd_queue_work(server, send_async, arg) != ESP_OK) {
                    free(data_copy);
                    free(arg);
                }
             } else {
                 free(data_copy);
             }
        }
    }
    
    cJSON_Delete(root);
    free(json_str);
}
