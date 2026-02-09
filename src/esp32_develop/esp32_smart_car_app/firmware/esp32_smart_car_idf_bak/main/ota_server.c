#include <string.h>
#include <sys/param.h>
#include "esp_log.h"
#include "esp_ota_ops.h"
#include "esp_http_server.h"
#include "esp_flash_partitions.h"
#include "esp_partition.h"
#include "esp_system.h"
#include "cJSON.h" 
#include "ota_server.h"
#include "wifi_app.h"

static const char *TAG = "ota_server";

/* HTML Form that sends raw file content via AJAX/Fetch */
static const char *ota_upload_form =
    "<!DOCTYPE html>"
    "<html>"
    "<head><meta name='viewport' content='width=device-width, initial-scale=1'></head>"
    "<body>"
    "<h1>ESP32-S3 OTA Update</h1>"
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

// WiFi Configuration Handler
// POST /wifi {"ssid": "...", "password": "..."}
static esp_err_t wifi_config_post_handler(httpd_req_t *req)
{
    char buf[200]; // Max WiFi config JSON size
    int ret, remaining = req->content_len;

    if (remaining >= sizeof(buf)) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    ret = httpd_req_recv(req, buf, remaining);
    if (ret <= 0) {
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) {
            httpd_resp_send_408(req);
        }
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
        
        ESP_LOGI(TAG, "Received WiFi Config: SSID=%s", ssid);
        
        httpd_resp_sendstr(req, "WiFi Saved. Restarting...");
        
        // Save and Restart
        wifi_save_credentials(ssid, pass);
    } else {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing SSID");
    }

    cJSON_Delete(root);
    return ESP_OK;
}

static esp_err_t root_get_handler(httpd_req_t *req)
{
    httpd_resp_send(req, "<h1>ESP32-S3 Smart Car Online</h1><p>System is running.</p>", HTTPD_RESP_USE_STRLEN);
    return ESP_OK;
}

static const httpd_uri_t root_get = {
    .uri       = "/",
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

void init_ota_server(void)
{
    httpd_handle_t server = NULL;
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 8080; 
    config.ctrl_port = 32769; 
    
    // Config already set in sdkconfig:
    // CONFIG_HTTPD_MAX_REQ_HDR_LEN=4096
    // CONFIG_HTTPD_MAX_URI_LEN=4096

    ESP_LOGI(TAG, "Starting HTTP (OTA/Config) server on port: '%d'", config.server_port);
    if (httpd_start(&server, &config) == ESP_OK) {
        httpd_register_uri_handler(server, &root_get);
        httpd_register_uri_handler(server, &ota_get);
        httpd_register_uri_handler(server, &ota_post);
        httpd_register_uri_handler(server, &wifi_post);
        ESP_LOGI(TAG, "HTTP Server started");
    } else {
        ESP_LOGI(TAG, "Error starting HTTP server!");
    }
}
