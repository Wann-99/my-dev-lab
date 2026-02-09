#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_err.h"
#include "rom/ets_sys.h"
#include "ultrasonic.h"

#include <stdlib.h>

#define TRIG_PIN 9
#define ECHO_PIN 10
#define TIMEOUT_US 30000 // 30ms timeout (approx 5m)
#define SAMPLE_COUNT 5   // Number of samples for filtering

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

static float measure_raw_distance(void)
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
            return -1;
        }
    }

    // Measure time
    int64_t start = esp_timer_get_time();
    while (gpio_get_level(ECHO_PIN) == 1) {
        if (esp_timer_get_time() - start > TIMEOUT_US) {
            return -1;
        }
    }
    int64_t end = esp_timer_get_time();

    float duration = (float)(end - start);
    // Distance = (Time * Speed of Sound) / 2
    // Speed of sound = 343.5 m/s at 20C = 0.03435 cm/us
    return duration * 0.03435f / 2.0f;
}

// Simple bubble sort for median
static void sort_array(float *array, int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (array[j] > array[j + 1]) {
                float temp = array[j];
                array[j] = array[j + 1];
                array[j + 1] = temp;
            }
        }
    }
}

float ultrasonic_get_distance_cm(void)
{
    float samples[SAMPLE_COUNT];
    int valid_samples = 0;

    for (int i = 0; i < SAMPLE_COUNT; i++) {
        float d = measure_raw_distance();
        if (d > 0 && d < 400) { // Valid range 2cm - 400cm
            samples[valid_samples++] = d;
        }
        // Small delay between samples to avoid interference from echoes
        vTaskDelay(pdMS_TO_TICKS(10)); 
    }

    if (valid_samples == 0) return -1.0f;
    if (valid_samples == 1) return samples[0];

    // Median Filter
    sort_array(samples, valid_samples);
    
    // If we have enough samples, return the average of the middle ones 
    // to achieve ±0.1cm stability
    if (valid_samples >= 3) {
        // Remove min and max, average the rest
        float sum = 0;
        for (int i = 1; i < valid_samples - 1; i++) {
            sum += samples[i];
        }
        return sum / (valid_samples - 2);
    } else {
        return samples[valid_samples / 2];
    }
}
