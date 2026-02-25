#pragma once
#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

#define WIFI_SSID      CONFIG_ESP_WIFI_SSID
#define WIFI_PASS      CONFIG_ESP_WIFI_PASSWORD

// Event group for WiFi connection status
extern EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

void wifi_init_sta(void);

/**
 * @brief Update WiFi credentials and reconnect
 */
void wifi_update_credentials(const char* ssid, const char* pass);
