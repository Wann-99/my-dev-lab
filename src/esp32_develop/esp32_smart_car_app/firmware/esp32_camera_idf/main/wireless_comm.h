#ifndef WIRELESS_COMM_H
#define WIRELESS_COMM_H

#include "esp_err.h"

/**
 * @brief Initialize ESP-NOW wireless communication for Dual MCU link
 */
void wireless_comm_init(void);

/**
 * @brief Send a JSON response back to the S3 Main MCU
 */
void wireless_comm_send_response(const char* res_msg);

#endif // WIRELESS_COMM_H
