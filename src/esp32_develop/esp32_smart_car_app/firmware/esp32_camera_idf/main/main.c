#include <stdio.h>
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
#include "camera_pins.h"
#include "wifi_app.h"
#include "http_server.h"
#include "driver/gpio.h"
#include "driver/ledc.h"

static const char *TAG = "main";

#ifndef OV3660_PID
#define OV3660_PID 0x3660
#endif

// LEDC configuration for Flash LED
#define LEDC_TIMER              LEDC_TIMER_1
#define LEDC_MODE               LEDC_LOW_SPEED_MODE
#define LEDC_OUTPUT_IO          (LED_GPIO_NUM) // Define in camera_pins.h (usually 4)
#define LEDC_CHANNEL            LEDC_CHANNEL_1
#define LEDC_DUTY_RES           LEDC_TIMER_8_BIT // Set duty resolution to 8 bits
#define LEDC_FREQUENCY          (5000) // Frequency in Hertz. Set frequency at 5 kHz

static camera_config_t camera_config = {
    .pin_pwdn = PWDN_GPIO_NUM,
    .pin_reset = RESET_GPIO_NUM,
    .pin_xclk = XCLK_GPIO_NUM,
    .pin_sscb_sda = SIOD_GPIO_NUM,
    .pin_sscb_scl = SIOC_GPIO_NUM,

    .pin_d7 = Y9_GPIO_NUM,
    .pin_d6 = Y8_GPIO_NUM,
    .pin_d5 = Y7_GPIO_NUM,
    .pin_d4 = Y6_GPIO_NUM,
    .pin_d3 = Y5_GPIO_NUM,
    .pin_d2 = Y4_GPIO_NUM,
    .pin_d1 = Y3_GPIO_NUM,
    .pin_d0 = Y2_GPIO_NUM,
    .pin_vsync = VSYNC_GPIO_NUM,
    .pin_href = HREF_GPIO_NUM,
    .pin_pclk = PCLK_GPIO_NUM,

    .xclk_freq_hz = 20000000,
    .ledc_timer = LEDC_TIMER_0,
    .ledc_channel = LEDC_CHANNEL_0,

    .pixel_format = PIXFORMAT_JPEG, //YUV422,GRAYSCALE,RGB565,JPEG
    .frame_size = FRAMESIZE_VGA,    //Default to VGA for smooth streaming
    
    .jpeg_quality = 12, //0-63 lower number means higher quality
    .fb_count = 2,       //if more than one, i2s runs in continuous mode. Use only with JPEG
    .fb_location = CAMERA_FB_IN_PSRAM,
    .grab_mode = CAMERA_GRAB_LATEST
};

// Global function to set LED intensity (0-255)
static int s_led_duty = 0;

void set_led_intensity(int intensity)
{
#ifdef LED_GPIO_NUM
    if (intensity < 0) intensity = 0;
    if (intensity > 255) intensity = 255;
    s_led_duty = intensity;
    
    // Configure LEDC timer and channel if not already done? 
    // Usually done once. We can just set duty.
    // If intensity is 0, maybe we can just stop it, but 0 duty is fine.
    
    ledc_set_duty(LEDC_MODE, LEDC_CHANNEL, intensity);
    ledc_update_duty(LEDC_MODE, LEDC_CHANNEL);
    ESP_LOGI(TAG, "Set LED intensity: %d", intensity);
#endif
}

int get_led_intensity()
{
    return s_led_duty;
}

static void init_led_flash()
{
#ifdef LED_GPIO_NUM
    // Prepare and then apply the LEDC PWM timer configuration
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_MODE,
        .timer_num        = LEDC_TIMER,
        .duty_resolution  = LEDC_DUTY_RES,
        .freq_hz          = LEDC_FREQUENCY,  // Set output frequency at 5 kHz
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);

    // Prepare and then apply the LEDC PWM channel configuration
    ledc_channel_config_t ledc_channel = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = LEDC_OUTPUT_IO,
        .duty           = 0, // Set duty to 0%
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel);
    ESP_LOGI(TAG, "Flash LED initialized on GPIO %d", LEDC_OUTPUT_IO);
#endif
}

static esp_err_t init_camera()
{
    // Check PSRAM availability and adjust config
    if (heap_caps_get_total_size(MALLOC_CAP_SPIRAM) > 0) {
        ESP_LOGI(TAG, "PSRAM found! Using high quality settings");
        camera_config.frame_size = FRAMESIZE_UXGA;
        camera_config.jpeg_quality = 10;
        camera_config.fb_count = 2;
        camera_config.grab_mode = CAMERA_GRAB_LATEST;
        camera_config.fb_location = CAMERA_FB_IN_PSRAM;
    } else {
        ESP_LOGW(TAG, "PSRAM not found! Using lower quality settings");
        camera_config.frame_size = FRAMESIZE_SVGA;
        camera_config.jpeg_quality = 12;
        camera_config.fb_count = 1;
        camera_config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
        camera_config.fb_location = CAMERA_FB_IN_DRAM;
    }

    //initialize the camera
    esp_err_t err = esp_camera_init(&camera_config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Camera Init Failed");
        return err;
    }
    
    sensor_t * s = esp_camera_sensor_get();
    
    // Check PID and adjust
    if (s->id.PID == OV3660_PID) {
        ESP_LOGI(TAG, "OV3660 detected");
        s->set_vflip(s, 1); // Flip vertically (adjust based on mounting)
        s->set_brightness(s, 1); // Boost brightness slightly
        s->set_saturation(s, 0); // Natural saturation
        s->set_contrast(s, 1);   // Enhance contrast
        s->set_sharpness(s, 1);  // Sharpen edges
        s->set_ae_level(s, 0);   // Standard exposure target
        s->set_aec2(s, 1);       // Enable DSP-based auto exposure (better)
        s->set_awb_gain(s, 1);   // Enable auto white balance gain
        s->set_wb_mode(s, 0);    // Auto White Balance mode
        s->set_special_effect(s, 0); // No special effects
        s->set_gainceiling(s, (gainceiling_t)0); // Limit gain to 2x to reduce noise
        s->set_lenc(s, 1);       // Enable lens correction
    } else if (s->id.PID == OV2640_PID) {
        ESP_LOGI(TAG, "OV2640 detected");
        s->set_vflip(s, 1);
        s->set_brightness(s, 1);
        s->set_saturation(s, -2);
    } else {
        ESP_LOGI(TAG, "Camera detected with PID: 0x%x", s->id.PID);
    }
    
    // Drop down frame size for higher initial frame rate if needed
    if (heap_caps_get_total_size(MALLOC_CAP_SPIRAM) > 0) {
        s->set_framesize(s, FRAMESIZE_VGA); // VGA (640x480) for balance of quality and FPS
    } else {
        s->set_framesize(s, FRAMESIZE_QVGA); // Force QVGA if no PSRAM
    }
    
    return ESP_OK;
}

void app_main(void)
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Initialize Flash LED (LEDC)
    init_led_flash();

    ESP_LOGI(TAG, "Initializing WiFi...");
    wifi_init_sta();

    ESP_LOGI(TAG, "Initializing Camera...");
    if(init_camera() != ESP_OK) {
        ESP_LOGE(TAG, "Camera Init Failed. Restarting...");
        // esp_restart(); // Optional: restart if camera fails
    } else {
        ESP_LOGI(TAG, "Camera Init Success");
        start_webserver();
        ESP_LOGI(TAG, "Web Server Started");
    }

    while(1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
