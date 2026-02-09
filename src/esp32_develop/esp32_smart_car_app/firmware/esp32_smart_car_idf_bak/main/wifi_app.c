#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "lwip/err.h"
#include "lwip/sys.h"
#include "mdns.h"

#include "wifi_app.h"

/* FreeRTOS event group to signal when we are connected*/
static EventGroupHandle_t s_wifi_event_group;

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static const char *TAG = "wifi_mgr";
static int s_retry_num = 0;
#define MAX_RETRY 5

// Default SoftAP Config
#define AP_SSID "ESP32-SmartCar-Config"
#define AP_PASS "" // Open network

static void event_handler(void* arg, esp_event_base_t event_base,
                                int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_retry_num < MAX_RETRY) {
            esp_wifi_connect();
            s_retry_num++;
            ESP_LOGI(TAG, "retry to connect to the AP");
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
        }
        ESP_LOGI(TAG,"connect to the AP fail");
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_num = 0;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STACONNECTED) {
        wifi_event_ap_staconnected_t* event = (wifi_event_ap_staconnected_t*) event_data;
        (void)event;
        ESP_LOGI(TAG, "station "MACSTR" join, AID=%d",
                 MAC2STR(event->mac), event->aid);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STADISCONNECTED) {
        wifi_event_ap_stadisconnected_t* event = (wifi_event_ap_stadisconnected_t*) event_data;
        (void)event;
        ESP_LOGI(TAG, "station "MACSTR" leave, AID=%d",
                 MAC2STR(event->mac), event->aid);
    }
}

void start_mdns_service()
{
    esp_err_t err = mdns_init();
    if (err) {
        ESP_LOGE(TAG, "MDNS Init failed: %d", err);
        return;
    }
    mdns_hostname_set("smartcar");
    mdns_instance_name_set("Flexiv Smart Car");

    mdns_txt_item_t serviceTxtData[1] = {
        {"type", "smart_car"},
    };

    mdns_service_add("SmartCar-Web", "_smartcar", "_tcp", 8080, serviceTxtData, 1);
    ESP_LOGI(TAG, "mDNS service started. Hostname: smartcar.local");
}

static void wifi_init_softap(void)
{
    ESP_LOGI(TAG, "Starting SoftAP...");
    
    // Stop WiFi if it was started (e.g. failed STA connection)
    esp_wifi_stop();
    
    esp_netif_create_default_wifi_ap();

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = AP_SSID,
            .ssid_len = strlen(AP_SSID),
            .channel = 1,
            .password = AP_PASS,
            .max_connection = 4,
            .authmode = WIFI_AUTH_OPEN
        },
    };
    if (strlen(AP_PASS) == 0) {
        wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    }

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "SoftAP started. SSID: %s", AP_SSID);
    
    // Start mDNS here too so user can find it? 
    // Usually mDNS works on AP too if we bind it.
    start_mdns_service();
}

void wifi_init_manager(void)
{
    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    // Create both STA and AP netifs (we might use either)
    esp_netif_create_default_wifi_sta();
    // esp_netif_create_default_wifi_ap(); // Called in softap init if needed

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &event_handler,
                                                        NULL,
                                                        NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &event_handler,
                                                        NULL,
                                                        NULL));

    // 1. Try to load credentials from NVS
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("wifi_config", NVS_READONLY, &my_handle);
    
    char ssid[33] = {0};
    char password[65] = {0};
    size_t ssid_len = sizeof(ssid);
    size_t pass_len = sizeof(password);
    bool has_creds = false;

    if (err == ESP_OK) {
        if (nvs_get_str(my_handle, "ssid", ssid, &ssid_len) == ESP_OK &&
            nvs_get_str(my_handle, "password", password, &pass_len) == ESP_OK) {
            has_creds = true;
            ESP_LOGI(TAG, "Found saved credentials for SSID: %s", ssid);
        }
        nvs_close(my_handle);
    } else {
        ESP_LOGW(TAG, "No saved WiFi credentials found in NVS");
    }

    if (has_creds) {
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
        strncpy((char*)wifi_config.sta.password, password, sizeof(wifi_config.sta.password));

        ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
        ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
        ESP_ERROR_CHECK(esp_wifi_start());

        ESP_LOGI(TAG, "Connecting to WiFi...");
        EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                pdFALSE,
                pdFALSE,
                portMAX_DELAY);

        if (bits & WIFI_CONNECTED_BIT) {
            ESP_LOGI(TAG, "Connected to SSID:%s", ssid);
            start_mdns_service();
            return; // Success
        } else {
            ESP_LOGW(TAG, "Failed to connect to saved SSID. Switching to SoftAP.");
        }
    }

    // Fallback to SoftAP
    wifi_init_softap();
}

esp_err_t wifi_save_credentials(const char *ssid, const char *password)
{
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("wifi_config", NVS_READWRITE, &my_handle);
    if (err != ESP_OK) return err;

    err = nvs_set_str(my_handle, "ssid", ssid);
    if (err != ESP_OK) { nvs_close(my_handle); return err; }

    err = nvs_set_str(my_handle, "password", password);
    if (err != ESP_OK) { nvs_close(my_handle); return err; }

    err = nvs_commit(my_handle);
    nvs_close(my_handle);
    
    ESP_LOGI(TAG, "WiFi credentials saved. Restarting...");
    
    // Delay to allow HTTP response to be sent
    vTaskDelay(pdMS_TO_TICKS(1000));
    
    esp_restart();
    return ESP_OK;
}
