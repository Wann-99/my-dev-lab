#include "camera.h"
#include "esp_camera.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "CAMERA";

/* ===== GPIO 映射 ===== */
#define CAM_PIN_PWDN     -1
#define CAM_PIN_RESET    16
#define CAM_PIN_XCLK     40

#define CAM_PIN_SIOD     17
#define CAM_PIN_SIOC     18

#define CAM_PIN_D0       13
#define CAM_PIN_D1       3
#define CAM_PIN_D2       12
#define CAM_PIN_D3       47
#define CAM_PIN_D4       14
#define CAM_PIN_D5       45
#define CAM_PIN_D6       46
#define CAM_PIN_D7       48

#define CAM_PIN_VSYNC    21
#define CAM_PIN_HREF     38
#define CAM_PIN_PCLK     11

void camera_init(void)
{
    // 强制硬件复位逻辑
    if (CAM_PIN_RESET != -1) {
        gpio_config_t io_conf = {
            .intr_type = GPIO_INTR_DISABLE,
            .mode = GPIO_MODE_OUTPUT,
            .pin_bit_mask = (1ULL << CAM_PIN_RESET),
            .pull_down_en = 0,
            .pull_up_en = 0,
        };
        gpio_config(&io_conf);
        gpio_set_level(CAM_PIN_RESET, 0);
        vTaskDelay(pdMS_TO_TICKS(50));
        gpio_set_level(CAM_PIN_RESET, 1);
        vTaskDelay(pdMS_TO_TICKS(50));
    }

    camera_config_t config = {
        .ledc_channel = LEDC_CHANNEL_0,
        .ledc_timer   = LEDC_TIMER_0,

        .pin_d0       = CAM_PIN_D0,
        .pin_d1       = CAM_PIN_D1,
        .pin_d2       = CAM_PIN_D2,
        .pin_d3       = CAM_PIN_D3,
        .pin_d4       = CAM_PIN_D4,
        .pin_d5       = CAM_PIN_D5,
        .pin_d6       = CAM_PIN_D6,
        .pin_d7       = CAM_PIN_D7,

        .pin_xclk     = CAM_PIN_XCLK,
        .pin_pclk     = CAM_PIN_PCLK,
        .pin_vsync    = CAM_PIN_VSYNC,
        .pin_href     = CAM_PIN_HREF,

        .pin_sscb_sda = CAM_PIN_SIOD,
        .pin_sscb_scl = CAM_PIN_SIOC,

        .pin_pwdn     = CAM_PIN_PWDN,
        .pin_reset    = CAM_PIN_RESET,

        .xclk_freq_hz = 20000000,           // 20MHz
        .pixel_format = PIXFORMAT_JPEG,

        // 关键优化参数
        .frame_size   = FRAMESIZE_VGA,      
        .jpeg_quality = 12,                 
        .fb_count     = 2,                  // PSRAM DMA 模式建议至少使用 2 个缓冲区以防获取失败
        .fb_location  = CAMERA_FB_IN_PSRAM, 
        .grab_mode    = CAMERA_GRAB_WHEN_EMPTY, 
    };

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Camera init failed: %s", esp_err_to_name(err));
        return;
    }

    sensor_t *sensor = esp_camera_sensor_get();
    if (sensor) {
        sensor->set_vflip(sensor, 0);
        sensor->set_hmirror(sensor, 0);
        sensor->set_quality(sensor, 10); // 压缩率调整
    }

    ESP_LOGI(TAG, "Camera init OK");
}
