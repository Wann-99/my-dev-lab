#include <string.h>
#include "nvs_flash.h"
#include "esp_log.h"
#include "config_storage.h"

static const char *TAG = "config_storage";
static const char *NVS_NAMESPACE = "car_cfg";

esp_err_t load_car_config(car_config_t *config) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &handle);
    if (err != ESP_OK) {
        return err;
    }

    size_t len = MAX_CONFIG_LEN;
    err = nvs_get_str(handle, "relay_url", config->relay_url, &len);
    if (err == ESP_OK) {
        len = MAX_CONFIG_LEN;
        err = nvs_get_str(handle, "device_id", config->device_id, &len);
    }

    nvs_close(handle);
    return err;
}

esp_err_t save_car_config(const car_config_t *config) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_set_str(handle, "relay_url", config->relay_url);
    if (err == ESP_OK) {
        err = nvs_set_str(handle, "device_id", config->device_id);
    }

    if (err == ESP_OK) {
        err = nvs_commit(handle);
    }

    nvs_close(handle);
    return err;
}
