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
#include "ota_server.h"

#ifndef MIN
#define MIN(a,b) ((a)<(b)?(a):(b))
#endif

static const char *TAG = "ota_server";

/* HTML Form for ESP32-CAM OTA */
static const char *ota_upload_form =
    "<!DOCTYPE html>"
    "<html>"
    "<head><meta name='viewport' content='width=device-width, initial-scale=1'>"
    "<style>body { font-family: sans-serif; text-align: center; padding: 20px; }</style>"
    "</head>"
    "<body>"
    "<h1>ESP32-CAM OTA Update</h1>"
    "<p>Select firmware.bin for the camera module:</p>"
    "<input type='file' id='fileInput'><br><br>"
    "<button onclick='upload()'>Flash Camera</button>"
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
    "    if (xhr.status == 200) { status.innerText = 'Update Success! Rebooting...'; }"
    "    else { status.innerText = 'Error: ' + xhr.responseText; }"
    "  };"
    "  xhr.onerror = function() { status.innerText = 'Error during upload'; };"
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

    ESP_LOGI(TAG, "OTA: Starting update on partition %s", update_partition->label);

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

    ESP_LOGI(TAG, "OTA Update Success. Restarting...");
    httpd_resp_sendstr(req, "Update Success! Rebooting...");
    
    // Delay restart to allow response to be sent
    vTaskDelay(pdMS_TO_TICKS(1000));
    esp_restart();
    return ESP_OK;
}

void register_ota_handlers(httpd_handle_t server)
{
    if (server == NULL) return;

    httpd_uri_t ota_get = {
        .uri       = "/update",
        .method    = HTTP_GET,
        .handler   = ota_update_get_handler,
        .user_ctx  = NULL
    };
    httpd_register_uri_handler(server, &ota_get);

    httpd_uri_t ota_post = {
        .uri       = "/update",
        .method    = HTTP_POST,
        .handler   = ota_update_post_handler,
        .user_ctx  = NULL
    };
    httpd_register_uri_handler(server, &ota_post);
    
    ESP_LOGI(TAG, "OTA Handlers registered at /update");
}
