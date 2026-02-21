#ifndef OTA_SERVER_H
#define OTA_SERVER_H

#include "esp_http_server.h"

void register_ota_handlers(httpd_handle_t server);

/**
 * @brief Start OTA update from a given URL
 * 
 * @param url The URL of the firmware.bin file
 */
void ota_start_from_url(const char *url);

#endif // OTA_SERVER_H
