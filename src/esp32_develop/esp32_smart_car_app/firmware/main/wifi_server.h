#ifndef WIFI_SERVER_H
#define WIFI_SERVER_H

#include "cJSON.h"

typedef void (*command_callback_t)(cJSON *root);

void wifi_server_init(void);
void wifi_server_set_callback(command_callback_t cb);
void wifi_server_send_status(float dist, const char* mode);

#endif
