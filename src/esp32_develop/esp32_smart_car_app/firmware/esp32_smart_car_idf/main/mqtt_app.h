#ifndef MQTT_APP_H
#define MQTT_APP_H

#include "esp_err.h"

esp_err_t mqtt_app_start(void);
void mqtt_app_send_status(const char *json_status);

#endif
