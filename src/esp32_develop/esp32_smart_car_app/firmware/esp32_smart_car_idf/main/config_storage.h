#ifndef CONFIG_STORAGE_H
#define CONFIG_STORAGE_H

#include "esp_err.h"

#define MAX_CONFIG_LEN 128

typedef struct {
    char relay_url[MAX_CONFIG_LEN];
    char device_id[MAX_CONFIG_LEN];
} car_config_t;

/**
 * @brief Load car configuration from NVS
 * @param config Pointer to config struct
 * @return ESP_OK if loaded, ESP_ERR_NVS_NOT_FOUND if not found
 */
esp_err_t load_car_config(car_config_t *config);

/**
 * @brief Save car configuration to NVS
 * @param config Pointer to config struct
 * @return esp_err_t
 */
esp_err_t save_car_config(const car_config_t *config);

#endif // CONFIG_STORAGE_H
