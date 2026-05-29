#ifndef WIRELESS_COMM_H
#define WIRELESS_COMM_H

#include "esp_err.h"

/**
 * @brief Initialize ESP-NOW wireless communication for Dual MCU link
 */
void wireless_comm_init(void);

/**
 * @brief Send WiFi credentials to the other MCU wirelessly
 */
void wireless_comm_send_wifi_sync(const char* ssid, const char* password);

/**
 * @brief Send a command to control CAM features (e.g. Flash LED)
 */
void wireless_comm_send_cam_ctrl(const char* cmd, int value);

/**
 * @brief Send a PING command to verify wireless connection
 */
void wireless_comm_send_ping(void);

/**
 * @brief Get the last known IP of the Camera MCU
 */
const char* wireless_comm_get_cam_ip(void);

/**
 * @brief Save/Load CAM IP from NVS
 */
void wireless_comm_save_cam_ip(const char* ip);
void wireless_comm_load_cam_ip(void);

#endif // WIRELESS_COMM_H
