#pragma once

#include "esp_http_server.h"

httpd_handle_t websocket_server_init(void);
void websocket_server_broadcast(const char *msg);
