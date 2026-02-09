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
/**
 * @brief Get the device ID (based on MAC)
 * 
 * @param buf Buffer to store ID
 * @param len Buffer length
 */
void wifi_get_device_id(char *buf, size_t len);
