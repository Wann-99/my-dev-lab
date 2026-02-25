#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "mdns.h"
#include "cJSON.h"
#include "wifi_app.h"
#include "wireless_comm.h"
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

static void start_mdns_service(void)
{
    static bool mdns_started = false;
    if (mdns_started) return;

    esp_err_t err = mdns_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "MDNS Init failed: %d", err);
        return;
    }
    mdns_hostname_set("robocar-cam");
    mdns_instance_name_set("RoboCar Vision Module");
    
    mdns_service_add(NULL, "_http", "_tcp", 80, NULL, 0);
    mdns_service_add(NULL, "_mjpeg", "_tcp", 81, NULL, 0);
    mdns_started = true;
    ESP_LOGI(TAG, "mDNS started: robocar-cam.local");
}

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
        if (s_retry_num < 3) {
            gpio_set_level(LED_STATUS_GPIO_NUM, 0); 
            vTaskDelay(pdMS_TO_TICKS(2000)); 
            esp_wifi_connect();
            s_retry_num++;
            ESP_LOGI(TAG, "retry to connect to the AP (%d/3)", s_retry_num);
        } else {
            // CRITICAL: Stop calling esp_wifi_connect to free the radio for ESP-NOW channel hopping
            ESP_LOGW(TAG, "WiFi fail. Entering PURE LISTENING MODE for ESP-NOW sync...");
            xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
            // No esp_wifi_connect() here, just wait for wireless_comm to call wifi_update_credentials
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        char ip_str[16];
        esp_ip4addr_ntoa(&event->ip_info.ip, ip_str, sizeof(ip_str));
        ESP_LOGI(TAG, "Got IP: %s", ip_str);
        
        // Notify S3 about the Camera IP via Wireless
        cJSON *root = cJSON_CreateObject();
        cJSON_AddStringToObject(root, "res", "ip_info");
        cJSON_AddStringToObject(root, "ip", ip_str);
        char *out = cJSON_PrintUnformatted(root);
        if (out) {
            wireless_comm_send_response(out);
            free(out);
        }
        cJSON_Delete(root);

        s_retry_num = 0;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        
        start_mdns_service();

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
    ESP_ERROR_CHECK(esp_wifi_set_max_tx_power(78)); // Max TX power (approx 19.5dBm) for best range

    ESP_LOGI(TAG, "wifi_init_sta finished.");
}

void wifi_update_credentials(const char* ssid, const char* pass)
{
    ESP_LOGI(TAG, "Updating WiFi Credentials: %s", ssid);
    
    wifi_config_t wifi_config = {
        .sta = {
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {
                .capable = true,
                .required = false
            },
        },
    };
    strncpy((char*)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid));
    strncpy((char*)wifi_config.sta.password, pass, sizeof(wifi_config.sta.password));

    s_retry_num = 0; // Reset retry count for new credentials
    
    esp_wifi_disconnect();
    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
    esp_wifi_connect();
}
