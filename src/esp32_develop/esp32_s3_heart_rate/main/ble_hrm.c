#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include "nvs.h"
#include "nvs_flash.h"

#include "esp_bt.h"
#include "esp_gap_ble_api.h"
#include "esp_gattc_api.h"
#include "esp_gatts_api.h"
#include "esp_gatt_defs.h"
#include "esp_bt_main.h"
#include "esp_gatt_common_api.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"

#include "ble_hrm.h"
#include "ble_server.h" // Include the new header

#define TAG "BLE_HRM"

// Heart Rate Service UUID
#define REMOTE_SERVICE_UUID        0x180D
#define REMOTE_NOTIFY_CHAR_UUID    0x2A37

// Server Definitions
#define HR_PROFILE_NUM             1
#define HR_PROFILE_APP_ID          0
#define HR_SVC_INST_ID             0

// Client Definitions
#define INVALID_HANDLE   0

// Global State
static ble_hrm_callback_t s_hr_callback = NULL;
static bool s_connect = false;
static bool s_get_server = false;
static esp_gattc_char_elem_t *s_char_elem_result = NULL;
static esp_gattc_descr_elem_t *s_descr_elem_result = NULL;

// Server Handles
static uint16_t s_hr_service_handle = 0;
static uint16_t s_hr_char_handle = 0;
static uint16_t s_hr_descr_handle = 0;
static esp_gatt_if_t s_server_gatt_if = ESP_GATT_IF_NONE;
static uint16_t s_server_conn_id = 0;

// UUIDs
static esp_bt_uuid_t remote_filter_service_uuid = {
    .len = ESP_UUID_LEN_16,
    .uuid = {.uuid16 = REMOTE_SERVICE_UUID,},
};

static esp_bt_uuid_t remote_filter_char_uuid = {
    .len = ESP_UUID_LEN_16,
    .uuid = {.uuid16 = REMOTE_NOTIFY_CHAR_UUID,},
};

static esp_bt_uuid_t notify_uuid = {
    .len = ESP_UUID_LEN_16,
    .uuid = {.uuid16 = ESP_GATT_UUID_CHAR_CLIENT_CONFIG,},
};

// Advertising Data
static esp_ble_adv_data_t adv_data = {
    .set_scan_rsp = false,
    .include_name = true,
    .include_txpower = false,
    .min_interval = 0x0006,
    .max_interval = 0x0010,
    .appearance = 0x00,
    .manufacturer_len = 0,
    .p_manufacturer_data =  NULL,
    .service_data_len = 0,
    .p_service_data = NULL,
    .service_uuid_len = 0,
    .p_service_uuid = NULL,
    .flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT),
};

static esp_ble_adv_params_t adv_params = {
    .adv_int_min        = 0x20,
    .adv_int_max        = 0x40,
    .adv_type           = ADV_TYPE_IND,
    .own_addr_type      = BLE_ADDR_TYPE_PUBLIC,
    .channel_map        = ADV_CHNL_ALL,
    .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

// Scan Parameters
static esp_ble_scan_params_t ble_scan_params = {
    .scan_type              = BLE_SCAN_TYPE_ACTIVE,
    .own_addr_type          = BLE_ADDR_TYPE_PUBLIC,
    .scan_filter_policy     = BLE_SCAN_FILTER_ALLOW_ALL,
    .scan_interval          = 0x50,
    .scan_window            = 0x30,
    .scan_duplicate         = BLE_SCAN_DUPLICATE_DISABLE
};

// Forward Declarations
static void esp_gap_cb(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param);
static void esp_gattc_cb(esp_gattc_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gattc_cb_param_t *param);
static void esp_gatts_cb(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param);
static void gattc_profile_event_handler(esp_gattc_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gattc_cb_param_t *param);
static void gatts_profile_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param);

// Client Profile Structure
struct gattc_profile_inst {
    esp_gattc_cb_t gattc_cb;
    uint16_t gattc_if;
    uint16_t app_id;
    uint16_t conn_id;
    uint16_t service_start_handle;
    uint16_t service_end_handle;
    uint16_t char_handle;
    esp_bd_addr_t remote_bda;
};

static struct gattc_profile_inst gl_profile_tab[1] = {
    [0] = {
        .gattc_cb = gattc_profile_event_handler,
        .gattc_if = ESP_GATT_IF_NONE,
    },
};

// Server Profile Structure
struct gatts_profile_inst {
    esp_gatts_cb_t gatts_cb;
    uint16_t gatts_if;
    uint16_t app_id;
    uint16_t conn_id;
    uint16_t service_handle;
    esp_gatt_srvc_id_t service_id;
    uint16_t char_handle;
    esp_bt_uuid_t char_uuid;
    esp_gatt_perm_t perm;
    esp_gatt_char_prop_t property;
    uint16_t descr_handle;
    esp_bt_uuid_t descr_uuid;
};

static struct gatts_profile_inst gl_server_tab[HR_PROFILE_NUM] = {
    [HR_PROFILE_APP_ID] = {
        .gatts_cb = gatts_profile_event_handler,
        .gatts_if = ESP_GATT_IF_NONE,
    },
};

// --- GAP Callback ---
static void esp_gap_cb(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param)
{
    uint8_t *adv_name = NULL;
    uint8_t adv_name_len = 0;
    
    switch (event) {
    // Scan Events
    case ESP_GAP_BLE_SCAN_PARAM_SET_COMPLETE_EVT:
        esp_ble_gap_start_scanning(30);
        break;
    case ESP_GAP_BLE_SCAN_START_COMPLETE_EVT:
        if (param->scan_start_cmpl.status != ESP_BT_STATUS_SUCCESS) {
            ESP_LOGE(TAG, "Scan start failed");
        } else {
            ESP_LOGI(TAG, "Scan started successfully");
        }
        break;
    case ESP_GAP_BLE_SCAN_RESULT_EVT: {
        esp_ble_gap_cb_param_t *scan_result = (esp_ble_gap_cb_param_t *)param;
        switch (scan_result->scan_rst.search_evt) {
        case ESP_GAP_SEARCH_INQ_RES_EVT:
            adv_name = esp_ble_resolve_adv_data(scan_result->scan_rst.ble_adv, ESP_BLE_AD_TYPE_NAME_CMPL, &adv_name_len);
            bool found = false;
            // Check UUID 0x180D in raw data (Little Endian 0x0D, 0x18)
            uint8_t *adv = scan_result->scan_rst.ble_adv;
            if (scan_result->scan_rst.adv_data_len > 2) {
                for (int i=0; i < scan_result->scan_rst.adv_data_len - 1; i++) {
                    if (adv[i] == 0x0D && adv[i+1] == 0x18) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found && adv_name) {
                if (strnstr((const char*)adv_name, "Mi", adv_name_len) || 
                    strnstr((const char*)adv_name, "Band", adv_name_len) ||
                    strnstr((const char*)adv_name, "Huawei", adv_name_len) ||
                    strnstr((const char*)adv_name, "Honor", adv_name_len)) {
                    found = true;
                }
            }

            if (found && !s_connect) {
                s_connect = true;
                ESP_LOGI(TAG, "Connecting to device...");
                esp_ble_gap_stop_scanning();
                esp_ble_gattc_open(gl_profile_tab[0].gattc_if, scan_result->scan_rst.bda, scan_result->scan_rst.ble_addr_type, true);
            }
            break;
        default: break;
        }
        break;
    }
    
    // Advertising Events
    case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
        esp_ble_gap_start_advertising(&adv_params);
        break;
    case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
        if (param->adv_start_cmpl.status != ESP_BT_STATUS_SUCCESS) {
            ESP_LOGE(TAG, "Advertising start failed");
        }
        break;
        
    default:
        break;
    }
}

// --- GATTC (Client) Callback ---
static void gattc_profile_event_handler(esp_gattc_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gattc_cb_param_t *param)
{
    esp_ble_gattc_cb_param_t *p_data = (esp_ble_gattc_cb_param_t *)param;

    switch (event) {
    case ESP_GATTC_REG_EVT:
        esp_ble_gap_set_scan_params(&ble_scan_params);
        break;
    case ESP_GATTC_CONNECT_EVT:
        gl_profile_tab[0].conn_id = p_data->connect.conn_id;
        memcpy(gl_profile_tab[0].remote_bda, p_data->connect.remote_bda, sizeof(esp_bd_addr_t));
        esp_ble_gattc_send_mtu_req (gattc_if, p_data->connect.conn_id);
        break;
    case ESP_GATTC_OPEN_EVT:
        if (p_data->open.status != ESP_GATT_OK) {
            ESP_LOGE(TAG, "Open failed");
        }
        break;
    case ESP_GATTC_DIS_SRVC_CMPL_EVT:
        if (p_data->dis_srvc_cmpl.status == ESP_GATT_OK) {
            esp_ble_gattc_search_service(gattc_if, p_data->dis_srvc_cmpl.conn_id, &remote_filter_service_uuid);
        }
        break;
    case ESP_GATTC_SEARCH_RES_EVT:
        if (p_data->search_res.srvc_id.uuid.len == ESP_UUID_LEN_16 && p_data->search_res.srvc_id.uuid.uuid.uuid16 == REMOTE_SERVICE_UUID) {
            s_get_server = true;
            gl_profile_tab[0].service_start_handle = p_data->search_res.start_handle;
            gl_profile_tab[0].service_end_handle = p_data->search_res.end_handle;
        }
        break;
    case ESP_GATTC_SEARCH_CMPL_EVT:
        if (s_get_server) {
            uint16_t count = 0;
            esp_ble_gattc_get_attr_count(gattc_if, p_data->search_cmpl.conn_id, ESP_GATT_DB_CHARACTERISTIC, 
                                         gl_profile_tab[0].service_start_handle, gl_profile_tab[0].service_end_handle, INVALID_HANDLE, &count);
            if (count > 0) {
                s_char_elem_result = (esp_gattc_char_elem_t *)malloc(sizeof(esp_gattc_char_elem_t) * count);
                if (s_char_elem_result) {
                    esp_ble_gattc_get_char_by_uuid(gattc_if, p_data->search_cmpl.conn_id, gl_profile_tab[0].service_start_handle, 
                                                  gl_profile_tab[0].service_end_handle, remote_filter_char_uuid, s_char_elem_result, &count);
                    if (count > 0 && (s_char_elem_result[0].properties & ESP_GATT_CHAR_PROP_BIT_NOTIFY)) {
                        gl_profile_tab[0].char_handle = s_char_elem_result[0].char_handle;
                        esp_ble_gattc_register_for_notify(gattc_if, gl_profile_tab[0].remote_bda, s_char_elem_result[0].char_handle);
                    }
                    free(s_char_elem_result);
                }
            }
        }
        break;
    case ESP_GATTC_REG_FOR_NOTIFY_EVT: {
        uint16_t count = 0;
        uint16_t notify_en = 1;
        esp_ble_gattc_get_attr_count(gattc_if, gl_profile_tab[0].conn_id, ESP_GATT_DB_DESCRIPTOR, 
                                     gl_profile_tab[0].service_start_handle, gl_profile_tab[0].service_end_handle, 
                                     gl_profile_tab[0].char_handle, &count);
        if (count > 0) {
            s_descr_elem_result = malloc(sizeof(esp_gattc_descr_elem_t) * count);
            if (s_descr_elem_result) {
                esp_ble_gattc_get_descr_by_char_handle(gattc_if, gl_profile_tab[0].conn_id, p_data->reg_for_notify.handle, 
                                                       notify_uuid, s_descr_elem_result, &count);
                if (count > 0 && s_descr_elem_result[0].uuid.uuid.uuid16 == ESP_GATT_UUID_CHAR_CLIENT_CONFIG) {
                    esp_ble_gattc_write_char_descr(gattc_if, gl_profile_tab[0].conn_id, s_descr_elem_result[0].handle, 
                                                   sizeof(notify_en), (uint8_t *)&notify_en, ESP_GATT_WRITE_TYPE_RSP, ESP_GATT_AUTH_REQ_NONE);
                }
                free(s_descr_elem_result);
            }
        }
        break;
    }
    case ESP_GATTC_NOTIFY_EVT:
        if (p_data->notify.value_len >= 2) {
            uint8_t *data = p_data->notify.value;
            uint8_t flags = data[0];
            uint16_t hr_val = 0;
            int offset = 1;
            if (flags & 0x01) { // 16-bit HR
                hr_val = data[offset] | (data[offset+1] << 8);
            } else { // 8-bit HR
                hr_val = data[offset];
            }
            if (s_hr_callback) s_hr_callback(hr_val);
            
            // Relay to Server
            ble_server_update_hr(hr_val);
        }
        break;
    case ESP_GATTC_DISCONNECT_EVT:
        s_connect = false;
        s_get_server = false;
        esp_ble_gap_start_scanning(30);
        break;
    default: break;
    }
}

static void esp_gattc_cb(esp_gattc_cb_event_t event, esp_gatt_if_t gattc_if, esp_ble_gattc_cb_param_t *param)
{
    if (event == ESP_GATTC_REG_EVT) {
        if (param->reg.status == ESP_GATT_OK) gl_profile_tab[param->reg.app_id].gattc_if = gattc_if;
    }
    if (gattc_if == ESP_GATT_IF_NONE || gattc_if == gl_profile_tab[0].gattc_if) {
        if (gl_profile_tab[0].gattc_cb) gl_profile_tab[0].gattc_cb(event, gattc_if, param);
    }
}

// --- GATTS (Server) Callback ---
static void gatts_profile_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param)
{
    switch (event) {
    case ESP_GATTS_REG_EVT:
        esp_ble_gap_set_device_name("ESP32_HRM_RELAY");
        esp_ble_gap_config_adv_data(&adv_data);
        
        // Create Service
        esp_gatt_srvc_id_t service_id;
        service_id.is_primary = true;
        service_id.id.inst_id = 0x00;
        service_id.id.uuid.len = ESP_UUID_LEN_16;
        service_id.id.uuid.uuid.uuid16 = REMOTE_SERVICE_UUID;
        esp_ble_gatts_create_service(gatts_if, &service_id, 4);
        break;
    case ESP_GATTS_CREATE_EVT:
        s_hr_service_handle = param->create.service_handle;
        gl_server_tab[HR_PROFILE_APP_ID].service_handle = param->create.service_handle;
        
        esp_ble_gatts_start_service(s_hr_service_handle);
        
        // Add Characteristic
        esp_bt_uuid_t char_uuid;
        char_uuid.len = ESP_UUID_LEN_16;
        char_uuid.uuid.uuid16 = REMOTE_NOTIFY_CHAR_UUID;
        
        esp_ble_gatts_add_char(s_hr_service_handle, &char_uuid, 
                               ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE,
                               ESP_GATT_CHAR_PROP_BIT_NOTIFY | ESP_GATT_CHAR_PROP_BIT_READ, 
                               NULL, NULL);
        break;
    case ESP_GATTS_ADD_CHAR_EVT:
        s_hr_char_handle = param->add_char.attr_handle;
        // Add Descriptor
        esp_bt_uuid_t descr_uuid;
        descr_uuid.len = ESP_UUID_LEN_16;
        descr_uuid.uuid.uuid16 = ESP_GATT_UUID_CHAR_CLIENT_CONFIG;
        esp_ble_gatts_add_char_descr(s_hr_service_handle, &descr_uuid, 
                                     ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE, NULL, NULL);
        break;
    case ESP_GATTS_ADD_CHAR_DESCR_EVT:
        s_hr_descr_handle = param->add_char_descr.attr_handle;
        break;
    case ESP_GATTS_CONNECT_EVT:
        s_server_conn_id = param->connect.conn_id;
        s_server_gatt_if = gatts_if;
        break;
    case ESP_GATTS_DISCONNECT_EVT:
        s_server_conn_id = 0;
        esp_ble_gap_start_advertising(&adv_params);
        break;
    default:
        break;
    }
}

static void esp_gatts_cb(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param)
{
    if (event == ESP_GATTS_REG_EVT) {
        if (param->reg.status == ESP_GATT_OK) gl_server_tab[param->reg.app_id].gatts_if = gatts_if;
    }
    if (gatts_if == ESP_GATT_IF_NONE || gatts_if == gl_server_tab[0].gatts_if) {
        if (gl_server_tab[0].gatts_cb) gl_server_tab[0].gatts_cb(event, gatts_if, param);
    }
}

// --- Public API ---

void ble_hrm_init(ble_hrm_callback_t callback)
{
    s_hr_callback = callback;

    ESP_ERROR_CHECK(esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT));

    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    esp_bt_controller_init(&bt_cfg);
    esp_bt_controller_enable(ESP_BT_MODE_BLE);
    esp_bluedroid_init();
    esp_bluedroid_enable();

    esp_ble_gap_register_callback(esp_gap_cb);
    esp_ble_gattc_register_callback(esp_gattc_cb);
    esp_ble_gatts_register_callback(esp_gatts_cb);

    esp_ble_gattc_app_register(0);
    esp_ble_gatts_app_register(0);
    
    esp_ble_gatt_set_local_mtu(500);
}

void ble_hrm_start_scan(void)
{
    if (!s_connect) {
        esp_ble_gap_start_scanning(30);
    }
}

void ble_server_init(void)
{
    // Included in ble_hrm_init
}

void ble_server_update_hr(uint16_t hr_val)
{
    if (s_server_conn_id != 0 && s_server_gatt_if != ESP_GATT_IF_NONE) {
        uint8_t data[2];
        data[0] = 0x00; // 8-bit format
        data[1] = (uint8_t)hr_val; // Truncate to 8-bit for simplicity or change format
        if (hr_val > 255) {
            data[0] = 0x01; // 16-bit
            // Need 3 bytes
            uint8_t data16[3];
            data16[0] = 0x01;
            data16[1] = hr_val & 0xFF;
            data16[2] = (hr_val >> 8) & 0xFF;
            esp_ble_gatts_send_indicate(s_server_gatt_if, s_server_conn_id, s_hr_char_handle, 3, data16, false);
        } else {
            esp_ble_gatts_send_indicate(s_server_gatt_if, s_server_conn_id, s_hr_char_handle, 2, data, false);
        }
    }
}
