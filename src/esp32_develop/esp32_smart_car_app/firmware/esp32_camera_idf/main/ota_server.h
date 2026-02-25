#ifndef OTA_SERVER_H
#define OTA_SERVER_H

#include "esp_http_server.h"

/**
 * @brief Registers the OTA update handlers (GET /update, POST /update)
 * 
 * @param server Handle to the existing HTTP server
 */
void register_ota_handlers(httpd_handle_t server);

#endif // OTA_SERVER_H
