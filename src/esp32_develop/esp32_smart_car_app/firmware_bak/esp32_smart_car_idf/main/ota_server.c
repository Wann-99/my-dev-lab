#include <string.h>
#include <stdlib.h>
#include <sys/param.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_ota_ops.h"
#include "esp_http_server.h"
#include "esp_flash_partitions.h"
#include "esp_partition.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_http_client.h"
#include "esp_https_ota.h"
#include "cJSON.h" 
#include "ota_server.h"
#include "wifi_app.h"

#ifndef MIN
#define MIN(a,b) ((a)<(b)?(a):(b))
#endif

static const char *TAG = "ota_server";

/* HTML Form that sends raw file content via AJAX/Fetch */
static const char *ota_upload_form =
    "<!DOCTYPE html>"
    "<html>"
    "<head><meta name='viewport' content='width=device-width, initial-scale=1'></head>"
    "<body>"
    "<h1>RoboCar-A OTA Update</h1>"
    "<p>Select firmware.bin file:</p>"
    "<input type='file' id='fileInput'><br><br>"
    "<button onclick='upload()'>Update Firmware</button>"
    "<div id='status' style='margin-top:20px;'></div>"
    "<script>"
    "function upload() {"
    "  var fileInput = document.getElementById('fileInput');"
    "  var file = fileInput.files[0];"
    "  if (!file) { alert('Please select a file'); return; }"
    "  var status = document.getElementById('status');"
    "  status.innerText = 'Uploading...';"
    "  var xhr = new XMLHttpRequest();"
    "  xhr.open('POST', '/update', true);"
    "  xhr.onload = function() {"
    "    status.innerText = 'Status: ' + xhr.responseText;"
    "  };"
    "  xhr.onerror = function() {"
    "    status.innerText = 'Error during upload';"
    "  };"
    "  xhr.send(file);"
    "}"
    "</script>"
    "</body>"
    "</html>";

static esp_err_t ota_update_get_handler(httpd_req_t *req)
{
    httpd_resp_send(req, ota_upload_form, HTTPD_RESP_USE_STRLEN);
    return ESP_OK;
}

static esp_err_t ota_update_post_handler(httpd_req_t *req)
{
    esp_ota_handle_t update_handle = 0;
    const esp_partition_t *update_partition = NULL;
    char buf[1024];
    esp_err_t err;
    int remaining = req->content_len;
    int received;

    update_partition = esp_ota_get_next_update_partition(NULL);
    if (update_partition == NULL) {
        ESP_LOGE(TAG, "No partition to update");
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "Writing to partition subtype %d at offset 0x%lx",
             update_partition->subtype, update_partition->address);

    err = esp_ota_begin(update_partition, OTA_SIZE_UNKNOWN, &update_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_begin failed (%s)", esp_err_to_name(err));
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    while (remaining > 0) {
        received = httpd_req_recv(req, buf, MIN(remaining, sizeof(buf)));
        if (received <= 0) {
            if (received == HTTPD_SOCK_ERR_TIMEOUT) {
                continue;
            }
            ESP_LOGE(TAG, "File receive failed");
            esp_ota_end(update_handle);
            httpd_resp_send_500(req);
            return ESP_FAIL;
        }

        err = esp_ota_write(update_handle, buf, received);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_ota_write failed (%s)", esp_err_to_name(err));
            esp_ota_end(update_handle);
            httpd_resp_send_500(req);
            return ESP_FAIL;
        }
        remaining -= received;
    }

    err = esp_ota_end(update_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_end failed (%s)", esp_err_to_name(err));
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    err = esp_ota_set_boot_partition(update_partition);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_set_boot_partition failed (%s)", esp_err_to_name(err));
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "OTA update successful! Restarting...");
    httpd_resp_sendstr(req, "Update successful. Restarting in 3 seconds...");

    // Delay restart to allow response to be sent
    vTaskDelay(pdMS_TO_TICKS(3000));
    esp_restart();

    return ESP_OK;
}

static int compare_rssi(const void *a, const void *b)
{
    wifi_ap_record_t *record_a = (wifi_ap_record_t *)a;
    wifi_ap_record_t *record_b = (wifi_ap_record_t *)b;
    return record_b->rssi - record_a->rssi; // Descending order
}

// WiFi Configuration Handler
// POST /wifi {"ssid": "...", "password": "..."}
static esp_err_t wifi_config_post_handler(httpd_req_t *req)
{
    char buf[256]; // Increased buffer size
    int ret, remaining = req->content_len;

    if (remaining >= sizeof(buf)) {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "JSON too large");
        return ESP_FAIL;
    }

    ret = httpd_req_recv(req, buf, remaining);
    if (ret <= 0) {
        return ESP_FAIL;
    }
    buf[ret] = '\0';

    cJSON *root = cJSON_Parse(buf);
    if (root == NULL) {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON");
        return ESP_FAIL;
    }

    cJSON *ssid_item = cJSON_GetObjectItem(root, "ssid");
    cJSON *pass_item = cJSON_GetObjectItem(root, "password");

    if (cJSON_IsString(ssid_item) && (ssid_item->valuestring != NULL)) {
        const char *ssid = ssid_item->valuestring;
        const char *pass = (cJSON_IsString(pass_item) && pass_item->valuestring) ? pass_item->valuestring : "";
        
        ESP_LOGI(TAG, "New WiFi Config request: SSID=%s", ssid);
        
        // Prepare WiFi config
        wifi_config_t wifi_config;
        memset(&wifi_config, 0, sizeof(wifi_config_t));
        strlcpy((char*)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid));
        strlcpy((char*)wifi_config.sta.password, pass, sizeof(wifi_config.sta.password));
        
        // More robust STA settings
        wifi_config.sta.threshold.authmode = WIFI_AUTH_OPEN;
        wifi_config.sta.pmf_cfg.capable = true;
        wifi_config.sta.pmf_cfg.required = false;

        ESP_LOGI(TAG, "Testing connection to: %s", ssid);
        
        // Ensure we are in APSTA mode
        esp_wifi_set_mode(WIFI_MODE_APSTA);
        esp_wifi_disconnect(); // Disconnect existing STA if any
        esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
        esp_err_t connect_err = esp_wifi_connect();
        
        if (connect_err == ESP_OK) {
            int retry = 0;
            bool connected = false;
            // Wait up to 10 seconds for IP
            while (retry < 20) {
                vTaskDelay(pdMS_TO_TICKS(500));
                esp_netif_ip_info_t ip_info;
                esp_netif_t* netif = esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
                if (netif && esp_netif_get_ip_info(netif, &ip_info) == ESP_OK && ip_info.ip.addr != 0) {
                    connected = true;
                    break;
                }
                
                // Also check if we failed (optional: could check event group here if shared)
                retry++;
            }

            if (connected) {
                ESP_LOGI(TAG, "WiFi Verification Success!");
                httpd_resp_set_type(req, "application/json");
                httpd_resp_sendstr(req, "{\"status\":\"ok\", \"message\":\"Connected successfully! Device will now restart to save settings.\"}");
                
                // Save and restart
                vTaskDelay(pdMS_TO_TICKS(1000));
                wifi_save_credentials(ssid, pass);
            } else {
                ESP_LOGW(TAG, "WiFi Verification Timeout/Failed!");
                esp_wifi_disconnect(); // Stop trying
                httpd_resp_set_status(req, "401 Unauthorized");
                httpd_resp_sendstr(req, "{\"status\":\"error\", \"message\":\"Connection failed. Please check SSID and Password.\"}");
            }
        } else {
            ESP_LOGE(TAG, "Failed to initiate connection: %d", connect_err);
            httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Failed to start connection process");
        }
    } else {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing SSID");
    }

    cJSON_Delete(root);
    return ESP_OK;
}

// GET /wifi/scan
static esp_err_t wifi_scan_get_handler(httpd_req_t *req)
{
    uint16_t max_aps = 20;
    uint16_t ap_count = 0;
    
    // Ensure we are in a mode that allows scanning
    wifi_mode_t mode;
    esp_wifi_get_mode(&mode);
    if (mode == WIFI_MODE_NULL) {
        ESP_LOGE(TAG, "WiFi not initialized");
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    // If in STA mode, we should be careful, but APSTA or AP is fine
    if (mode == WIFI_MODE_STA) {
        esp_wifi_set_mode(WIFI_MODE_APSTA);
    }

    wifi_ap_record_t *ap_info = (wifi_ap_record_t *)malloc(sizeof(wifi_ap_record_t) * max_aps);
    if (ap_info == NULL) {
        ESP_LOGE(TAG, "Failed to allocate memory for scan");
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "Starting WiFi scan...");
    
    // Non-blocking scan start could be better, but blocking is simpler for HTTP handler
    // We use a small delay to let other tasks run
    vTaskDelay(pdMS_TO_TICKS(50));
    
    wifi_scan_config_t scan_config = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = false,
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
        .scan_time.active.min = 100,
        .scan_time.active.max = 250
    };

    esp_err_t ret = esp_wifi_scan_start(&scan_config, true);
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "Scan failed: %s", esp_err_to_name(ret));
        free(ap_info);
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "[]");
        return ESP_OK;
    }

    uint16_t actual_aps = max_aps;
    esp_wifi_scan_get_ap_records(&actual_aps, ap_info);
    esp_wifi_scan_get_ap_num(&ap_count);

    // Sort by RSSI
    if (actual_aps > 0) {
        qsort(ap_info, actual_aps, sizeof(wifi_ap_record_t), compare_rssi);
    }

    cJSON *root = cJSON_CreateArray();
    for (int i = 0; i < actual_aps; i++) {
        if (strlen((char *)ap_info[i].ssid) == 0) continue;
        
        // Filter out duplicate SSIDs (keep strongest)
        bool duplicate = false;
        for (int j = 0; j < i; j++) {
            if (strcmp((char *)ap_info[i].ssid, (char *)ap_info[j].ssid) == 0) {
                duplicate = true;
                break;
            }
        }
        if (duplicate) continue;

        cJSON *item = cJSON_CreateObject();
        cJSON_AddStringToObject(item, "ssid", (char *)ap_info[i].ssid);
        cJSON_AddNumberToObject(item, "rssi", ap_info[i].rssi);
        cJSON_AddNumberToObject(item, "auth", ap_info[i].authmode);
        cJSON_AddItemToArray(root, item);
        
        // Limit to 15 unique SSIDs to keep JSON size manageable
        if (cJSON_GetArraySize(root) >= 15) break;
    }

    free(ap_info);

    char *json_str = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);

    if (json_str == NULL) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    httpd_resp_set_type(req, "application/json");
    // Add CORS headers just in case
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    httpd_resp_sendstr(req, json_str);
    
    free(json_str);
    return ESP_OK;
}

static esp_err_t root_get_handler(httpd_req_t *req)
{
    httpd_resp_send(req, "<h1>RoboCar-A Online</h1><p>System is running.</p>", HTTPD_RESP_USE_STRLEN);
    return ESP_OK;
}

static const httpd_uri_t status_get = {
    .uri       = "/status",
    .method    = HTTP_GET,
    .handler   = root_get_handler,
    .user_ctx  = NULL
};

static const httpd_uri_t ota_get = {
    .uri       = "/update",
    .method    = HTTP_GET,
    .handler   = ota_update_get_handler,
    .user_ctx  = NULL
};

static const httpd_uri_t ota_post = {
    .uri       = "/update",
    .method    = HTTP_POST,
    .handler   = ota_update_post_handler,
    .user_ctx  = NULL
};

static const httpd_uri_t wifi_post = {
    .uri       = "/wifi",
    .method    = HTTP_POST,
    .handler   = wifi_config_post_handler,
    .user_ctx  = NULL
};

static const httpd_uri_t wifi_scan_get = {
    .uri       = "/wifi/scan",
    .method    = HTTP_GET,
    .handler   = wifi_scan_get_handler,
    .user_ctx  = NULL
};

void register_ota_handlers(httpd_handle_t server)
{
    if (server == NULL) return;
    
    httpd_register_uri_handler(server, &status_get);
    httpd_register_uri_handler(server, &ota_get);
    httpd_register_uri_handler(server, &ota_post);
    httpd_register_uri_handler(server, &wifi_post);
    httpd_register_uri_handler(server, &wifi_scan_get);
    ESP_LOGI(TAG, "OTA/Config handlers registered on main server");
}

static void ota_task(void *pvParameter)
{
    char *url = (char *)pvParameter;
    ESP_LOGI(TAG, "Starting OTA update from: %s", url);

    esp_http_client_config_t config = {
        .url = url,
        .timeout_ms = 10000,
        .keep_alive_enable = true,
#if CONFIG_ESP_HTTPS_OTA_ALLOW_HTTP
        .skip_cert_common_name_check = true,
#endif
    };

    esp_https_ota_config_t ota_config = {
        .http_config = &config,
    };

    // For local HTTP OTA, we need to allow insecure connections if requested via http://
    // In some IDF versions, esp_https_ota still checks for certs even if URL is http
    // Setting use_global_ca_store to true satisfies the check without requiring a real cert
    config.use_global_ca_store = true;

    esp_err_t ret = esp_https_ota(&ota_config);
    if (ret == ESP_OK) {
        ESP_LOGI(TAG, "OTA Update Successful. Rebooting...");
        vTaskDelay(pdMS_TO_TICKS(1000));
        esp_restart();
    } else {
        ESP_LOGE(TAG, "OTA Update Failed! Error: %s", esp_err_to_name(ret));
    }

    free(url);
    vTaskDelete(NULL);
}

void ota_start_from_url(const char *url)
{
    if (url == NULL) return;
    
    // Copy URL to pass to task
    char *url_copy = strdup(url);
    if (url_copy == NULL) {
        ESP_LOGE(TAG, "Failed to allocate memory for OTA URL");
        return;
    }

    // Create a task to handle OTA to avoid blocking WS/HTTP server
    xTaskCreate(&ota_task, "ota_task", 8192, url_copy, 5, NULL);
}
