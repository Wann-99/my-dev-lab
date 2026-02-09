#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_err.h"
#include "rom/ets_sys.h"
#include "ultrasonic.h"

#define TRIG_PIN 9
#define ECHO_PIN 10
#define TIMEOUT_US 30000 // 30ms timeout (approx 5m)

void ultrasonic_init(void)
{
    gpio_config_t io_conf = {};
    
    // Configure TRIG
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << TRIG_PIN);
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    ESP_ERROR_CHECK(gpio_config(&io_conf));
    
    // Configure ECHO
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_INPUT;
    io_conf.pin_bit_mask = (1ULL << ECHO_PIN);
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    gpio_set_level(TRIG_PIN, 0);
}

float ultrasonic_get_distance_cm(void)
{
    // Trigger
    gpio_set_level(TRIG_PIN, 0);
    ets_delay_us(2);
    gpio_set_level(TRIG_PIN, 1);
    ets_delay_us(10);
    gpio_set_level(TRIG_PIN, 0);

    // Wait for Echo High
    int64_t start_wait = esp_timer_get_time();
    while (gpio_get_level(ECHO_PIN) == 0) {
        if (esp_timer_get_time() - start_wait > TIMEOUT_US) {
            // ESP_LOGW("Ultrasonic", "Timeout waiting for Echo HIGH");
            return -1;
        }
    }

    // Measure time
    int64_t start = esp_timer_get_time();
    while (gpio_get_level(ECHO_PIN) == 1) {
        if (esp_timer_get_time() - start > TIMEOUT_US) {
            // ESP_LOGW("Ultrasonic", "Timeout waiting for Echo LOW");
            return -1;
        }
    }
    int64_t end = esp_timer_get_time();

    float duration = (float)(end - start);
    // Distance = (Time * Speed of Sound) / 2
    // Speed of sound = 340 m/s = 0.034 cm/us
    return duration * 0.034 / 2;
}
