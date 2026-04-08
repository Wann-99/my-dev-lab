#include "esp_camera.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

static const char *TAG = "S3-CAM";

#define WIFI_GOT_IP_BIT BIT0
static EventGroupHandle_t s_wifi_event_group;

#define WIFI_SSID "CU_CctC"
#define WIFI_PASS "yx3eyz6h"

/* 若模组 PWDN 未接到该 GPIO，保持 -1，避免误驱动；确认需 GPIO38 再改 38 */
#define CAM_PIN_PWDN    -1
#define CAM_PIN_RESET   -1
#define CAM_PIN_XCLK    15
#define CAM_PIN_SIOD    4
#define CAM_PIN_SIOC    5

/* D 线整体高低位对调时试 1；多数板用 0（乐鑫 WROOM 参考） */
#define CAM_TRY_MIRROR_D0_D7  0

/* 场同步/行参考在硬件上与乐鑫参考对调时试 1 */
#define CAM_TRY_SWAP_VSYNC_HREF  0

#if CAM_TRY_MIRROR_D0_D7
#define CAM_PIN_D7      11
#define CAM_PIN_D6      9
#define CAM_PIN_D5      8
#define CAM_PIN_D4      10
#define CAM_PIN_D3      12
#define CAM_PIN_D2      18
#define CAM_PIN_D1      17
#define CAM_PIN_D0      16
#else
#define CAM_PIN_D7      16
#define CAM_PIN_D6      17
#define CAM_PIN_D5      18
#define CAM_PIN_D4      12
#define CAM_PIN_D3      10
#define CAM_PIN_D2      8
#define CAM_PIN_D1      9
#define CAM_PIN_D0      11
#endif

#if CAM_TRY_SWAP_VSYNC_HREF
#define CAM_PIN_VSYNC   7
#define CAM_PIN_HREF    6
#else
#define CAM_PIN_VSYNC   6
#define CAM_PIN_HREF    7
#endif
#define CAM_PIN_PCLK    13

// 🔥 标准 JPEG + 最稳配置
camera_config_t camera_config = {
    .pin_pwdn       = CAM_PIN_PWDN,
    .pin_reset      = CAM_PIN_RESET,
    .pin_xclk       = CAM_PIN_XCLK,
    .pin_sccb_sda   = CAM_PIN_SIOD,
    .pin_sccb_scl   = CAM_PIN_SIOC,

    .pin_d7         = CAM_PIN_D7,
    .pin_d6         = CAM_PIN_D6,
    .pin_d5         = CAM_PIN_D5,
    .pin_d4         = CAM_PIN_D4,
    .pin_d3         = CAM_PIN_D3,
    .pin_d2         = CAM_PIN_D2,
    .pin_d1         = CAM_PIN_D1,
    .pin_d0         = CAM_PIN_D0,

    .pin_vsync      = CAM_PIN_VSYNC,
    .pin_href       = CAM_PIN_HREF,
    .pin_pclk       = CAM_PIN_PCLK,

    .xclk_freq_hz   = 10000000,
    .ledc_timer     = LEDC_TIMER_0,
    .ledc_channel   = LEDC_CHANNEL_0,
    .pixel_format   = PIXFORMAT_JPEG,      // 必须 JPEG
    /* 更小帧减轻 8 位并行总线错误率，便于先验证通路 */
    .frame_size     = FRAMESIZE_QQVGA,
    .jpeg_quality   = 38,
    .fb_count       = 2,
    .grab_mode      = CAMERA_GRAB_LATEST,
    .fb_location    = CAMERA_FB_IN_DRAM,
};

static void wifi_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*)event_data;
        ESP_LOGI(TAG, "IP: " IPSTR, IP2STR(&event->ip_info.ip));
        ESP_LOGI(TAG, "流: http://" IPSTR "/stream  单帧: http://" IPSTR "/jpg",
                 IP2STR(&event->ip_info.ip), IP2STR(&event->ip_info.ip));
        if (s_wifi_event_group) {
            xEventGroupSetBits(s_wifi_event_group, WIFI_GOT_IP_BIT);
        }
    }
}

void wifi_init(void) {
    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL, NULL);
    esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL, NULL);

    wifi_config_t wifi_config = {
        .sta = {.ssid = WIFI_SSID, .password = WIFI_PASS},
    };

    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
    esp_wifi_start();
    /* 省电睡眠会拉长 DTIM 周期，与实时取流并存时偶发异常，拉流场景建议关闭 */
    esp_wifi_set_ps(WIFI_PS_NONE);
}

// --------------------------
// 🔥 标准 MJPEG 流（浏览器100%支持）
// --------------------------
static esp_err_t jpg_handler(httpd_req_t *req) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "no frame");
        return ESP_FAIL;
    }
    httpd_resp_set_type(req, "image/jpeg");
    httpd_resp_set_hdr(req, "Cache-Control", "no-store");
    esp_err_t err = httpd_resp_send(req, (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
    return err;
}

static esp_err_t stream_handler(httpd_req_t *req) {
    camera_fb_t *fb = NULL;
    httpd_resp_set_type(req, "multipart/x-mixed-replace;boundary=frame");
    httpd_resp_set_hdr(req, "Cache-Control", "no-store, no-cache");
    httpd_resp_set_hdr(req, "X-Accel-Buffering", "no");

    while (1) {
        fb = esp_camera_fb_get();
        if (!fb) {
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }

        char buf[64];
        snprintf(buf, sizeof(buf),
                "\r\n--frame\r\n"
                "Content-Type: image/jpeg\r\n"
                "Content-Length: %u\r\n\r\n", fb->len);

        httpd_resp_send_chunk(req, buf, strlen(buf));
        httpd_resp_send_chunk(req, (char*)fb->buf, fb->len);
        esp_camera_fb_return(fb);
    }
    return ESP_OK;
}

void start_server(void) {
    httpd_config_t conf = HTTPD_DEFAULT_CONFIG();
    conf.stack_size = 8192;
    httpd_handle_t server;
    httpd_start(&server, &conf);

    httpd_uri_t uri_stream = {
        .uri      = "/stream",
        .method   = HTTP_GET,
        .handler  = stream_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(server, &uri_stream);

    httpd_uri_t uri_jpg = {
        .uri      = "/jpg",
        .method   = HTTP_GET,
        .handler  = jpg_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(server, &uri_jpg);
}

void app_main(void) {
    nvs_flash_init();
    s_wifi_event_group = xEventGroupCreate();

    wifi_init();
    EventBits_t bits = xEventGroupWaitBits(
        s_wifi_event_group, WIFI_GOT_IP_BIT, pdFALSE, pdTRUE,
        pdMS_TO_TICKS(60000));
    if ((bits & WIFI_GOT_IP_BIT) == 0) {
        ESP_LOGE(TAG, "WiFi 未在超时内连上，未启动摄像头");
        return;
    }
    /* WiFi 稳定后再开 DVP，减少 RF 与并行总线同时工作导致的错码/NO-SOI */
    ESP_LOGI(TAG, "CAM mirror_d=%d swap_vh=%d pwdn=%d", CAM_TRY_MIRROR_D0_D7,
             CAM_TRY_SWAP_VSYNC_HREF, CAM_PIN_PWDN);
    esp_err_t cam_err = esp_camera_init(&camera_config);
    if (cam_err != ESP_OK) {
        ESP_LOGE(TAG, "esp_camera_init failed: %s", esp_err_to_name(cam_err));
        return;
    }
    start_server();
}