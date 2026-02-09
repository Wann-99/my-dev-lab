#pragma once

#include "esp_err.h"

/**
 * @brief Initialize WiFi Manager
 * - Tries to connect to saved WiFi (NVS)
 * - If fails, starts SoftAP (SSID: RoboCar-A-Config, No Password)
 */
void wifi_init_manager(void);

/**
 * @brief Save WiFi credentials to NVS and restart
 * 
 * @param ssid SSID to connect to
 * @param password Password
 * @return esp_err_t 
 */
esp_err_t wifi_save_credentials(const char *ssid, const char *password);
