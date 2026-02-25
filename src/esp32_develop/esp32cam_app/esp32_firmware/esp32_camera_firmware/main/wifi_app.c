#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "wifi_app.h"
#include "sdkconfig.h"
#include "camera_pins.h"
#include "driver/gpio.h"

static const char *TAG = "wifi_app";

#define WIFI_SSID      CONFIG_ESP_WIFI_SSID
#define WIFI_PASS      CONFIG_ESP_WIFI_PASSWORD
#define MAXIMUM_RETRY  CONFIG_ESP_MAXIMUM_RETRY

/* FreeRTOS event group to signal when we are connected*/
EventGroupHandle_t s_wifi_event_group;

static int s_retry_num = 0;

static void event_handler(void* arg, esp_event_base_t event_base,
                                int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        gpio_set_level(LED_STATUS_GPIO_NUM, 0); // Turn ON LED (Active Low)
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        gpio_set_level(LED_STATUS_GPIO_NUM, 1); // Turn OFF LED
        wifi_event_sta_disconnected_t* event = (wifi_event_sta_disconnected_t*) event_data;
        ESP_LOGE(TAG, "WiFi Disconnected. Reason: %d", event->reason);
        if (event->reason == WIFI_REASON_NO_AP_FOUND) {
            ESP_LOGW(TAG, "AP Not Found. Check SSID or Frequency (2.4GHz only).");
        }
        if (s_retry_num < MAXIMUM_RETRY) {
            gpio_set_level(LED_STATUS_GPIO_NUM, 0); // Turn ON LED for retry
            esp_wifi_connect();
            s_retry_num++;
            ESP_LOGI(TAG, "retry to connect to the AP");
        } else {
            xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
            ESP_LOGI(TAG, "connect to the AP fail");
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_num = 0;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        
        // Blink 3 times to indicate success
        for (int i = 0; i < 3; i++) {
            gpio_set_level(LED_STATUS_GPIO_NUM, 1); // OFF
            vTaskDelay(pdMS_TO_TICKS(100));
            gpio_set_level(LED_STATUS_GPIO_NUM, 0); // ON
            vTaskDelay(pdMS_TO_TICKS(100));
        }
        gpio_set_level(LED_STATUS_GPIO_NUM, 1); // Ensure OFF
    }
}

void wifi_init_sta(void)
{
    // Initialize Status LED
    gpio_reset_pin(LED_STATUS_GPIO_NUM);
    gpio_set_direction(LED_STATUS_GPIO_NUM, GPIO_MODE_OUTPUT);
    gpio_set_level(LED_STATUS_GPIO_NUM, 1); // Start OFF

    s_wifi_event_group = xEventGroupCreate();
    
    s_retry_num = 0;
    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASS,
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {
                .capable = true,
                .required = false
            },
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    ESP_LOGI(TAG, "wifi_init_sta finished.");
}
