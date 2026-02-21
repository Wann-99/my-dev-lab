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
#define AP_SSID "RoboCar-A-ConfigWiFi"
#define AP_PASS "" // Open network

static void event_handler(void* arg, esp_event_base_t event_base,
                                int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        ESP_LOGI(TAG, "STA started, connecting...");
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t* event = (wifi_event_sta_disconnected_t*) event_data;
        ESP_LOGW(TAG, "STA Disconnected. Reason: %d", event->reason);
        
        // Only retry if we are not intentionally disconnected and in STA/APSTA mode
        wifi_mode_t mode;
        if (esp_wifi_get_mode(&mode) == ESP_OK && (mode == WIFI_MODE_STA || mode == WIFI_MODE_APSTA)) {
            // Reason 15 is handshake timeout (usually wrong password)
            // Reason 201 is NO_AP_FOUND
            if (s_retry_num < MAX_RETRY) {
                s_retry_num++;
                ESP_LOGI(TAG, "Retry connection (%d/%d)...", s_retry_num, MAX_RETRY);
                vTaskDelay(pdMS_TO_TICKS(2000)); // Increased delay between retries
                esp_wifi_connect();
            } else {
                ESP_LOGE(TAG, "Max retries reached. Connection failed.");
                xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            }
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "STA Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_num = 0;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        start_mdns_service();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_START) {
        ESP_LOGI(TAG, "SoftAP started.");
        start_mdns_service();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STACONNECTED) {
        wifi_event_ap_staconnected_t* event = (wifi_event_ap_staconnected_t*) event_data;
        ESP_LOGI(TAG, "Station "MACSTR" joined, AID=%d", MAC2STR(event->mac), event->aid);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STADISCONNECTED) {
        wifi_event_ap_stadisconnected_t* event = (wifi_event_ap_stadisconnected_t*) event_data;
        ESP_LOGI(TAG, "Station "MACSTR" left, AID=%d", MAC2STR(event->mac), event->aid);
    }
}

void start_mdns_service(void)
{
    static bool mdns_started = false;
    if (mdns_started) {
        ESP_LOGI(TAG, "mDNS already started, updating records...");
        // If already started, we might just want to update or leave it
        // For now, let's just return to avoid re-init issues
        return; 
    }

    ESP_LOGI(TAG, "Starting mDNS service...");
    
    esp_err_t err = mdns_init();
    if (err != ESP_OK) {
        if (err == ESP_ERR_INVALID_STATE) {
            ESP_LOGW(TAG, "mDNS already initialized");
        } else {
            ESP_LOGE(TAG, "MDNS Init failed: %d", err);
            return;
        }
    }

    mdns_started = true;
    
    // 获取 MAC 地址生成唯一 ID
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    
    char hostname[32];
    snprintf(hostname, sizeof(hostname), "robocar-%02x%02x%02x", mac[3], mac[4], mac[5]);
    mdns_hostname_set(hostname);
    
    char device_id[32];
    // 必须匹配 App 期望的格式: id=robocar-a-v1-xxxxxx
    snprintf(device_id, sizeof(device_id), "robocar-a-v1-%02x%02x%02x", mac[3], mac[4], mac[5]);
    
    char instance_name[32];
    snprintf(instance_name, sizeof(instance_name), "RoboCar-A-%02x%02x%02x", mac[3], mac[4], mac[5]);
    mdns_instance_name_set(instance_name);

    // TXT records
    mdns_txt_item_t serviceTxtData[] = {
        {"id", device_id},
        {"type", "robocar-a"}, // 必须匹配 App 期望的 type=robocar-a
        {"path", "/ws"},
        {"version", "1.1.0"},
        {"auth", "no"}
    };

    // Add services
    // App 主要搜索 _robocar._tcp.local
    if (!mdns_service_exists("_robocar", "_tcp", NULL)) {
        ESP_ERROR_CHECK(mdns_service_add(instance_name, "_robocar", "_tcp", 80, serviceTxtData, 5));
    }
    if (!mdns_service_exists("_http", "_tcp", NULL)) {
        ESP_ERROR_CHECK(mdns_service_add(instance_name, "_http", "_tcp", 80, serviceTxtData, 5));
    }

    ESP_LOGI(TAG, "mDNS service started. Hostname: %s.local, Instance: %s", hostname, instance_name);
    ESP_LOGI(TAG, "TXT: id=%s, type=robocar-a", device_id);
}

static esp_netif_t *sta_netif = NULL;
static esp_netif_t *ap_netif = NULL;

static void wifi_init_softap(void)
{
    ESP_LOGI(TAG, "Starting SoftAP (APSTA mode)...");
    
    // Stop WiFi if it was started (e.g. failed STA connection)
    esp_wifi_stop();
    
    if (ap_netif == NULL) {
        ap_netif = esp_netif_create_default_wifi_ap();
    }

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

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA)); // Use APSTA to allow scanning without disconnecting AP
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    esp_wifi_set_ps(WIFI_PS_MIN_MODEM);
    esp_wifi_set_max_tx_power(60); // ~15dBm

    ESP_LOGI(TAG, "SoftAP started (APSTA mode). SSID: %s", AP_SSID);
    ESP_LOGI(TAG, "Connect your phone to this WiFi to configure the car.");
}

void wifi_init_manager(void)
{
    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    // Create both STA and AP netifs (we might use either)
    if (sta_netif == NULL) {
        sta_netif = esp_netif_create_default_wifi_sta();
    }
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
                .threshold.authmode = WIFI_AUTH_OPEN,
                .pmf_cfg = {
                    .capable = true,
                    .required = false
                },
                .sae_pwe_h2e = WPA3_SAE_PWE_BOTH,
            },
        };
        strncpy((char*)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid));
        strncpy((char*)wifi_config.sta.password, password, sizeof(wifi_config.sta.password));

        ESP_LOGI(TAG, "Attempting connection to saved WiFi: %s", ssid);
        ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
        ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
        ESP_ERROR_CHECK(esp_wifi_start());

        // Wait for connection or failure
        EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                pdFALSE,
                pdFALSE,
                pdMS_TO_TICKS(15000)); // Wait up to 15s

        if (bits & WIFI_CONNECTED_BIT) {
            ESP_LOGI(TAG, "Successfully connected to: %s", ssid);
            esp_wifi_set_ps(WIFI_PS_MIN_MODEM);
            return; 
        } else {
            ESP_LOGW(TAG, "Could not connect to saved WiFi. Falling back to SoftAP...");
        }
    }

    // Fallback to SoftAP
    wifi_init_softap();
}

esp_err_t wifi_reset_credentials(void)
{
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("wifi_config", NVS_READWRITE, &my_handle);
    if (err == ESP_OK) {
        nvs_erase_all(my_handle);
        nvs_commit(my_handle);
        nvs_close(my_handle);
        ESP_LOGI(TAG, "WiFi credentials erased. Restarting...");
        vTaskDelay(pdMS_TO_TICKS(1000));
        esp_restart();
    }
    return err;
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
