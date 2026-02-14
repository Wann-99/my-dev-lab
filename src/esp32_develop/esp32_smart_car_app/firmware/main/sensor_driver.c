#include "sensor_driver.h"
#include "config.h"
#include "esp_timer.h"
#include "rom/ets_sys.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void sensor_init(void) {
    // US
    gpio_set_direction(US_TRIG_PIN, GPIO_MODE_OUTPUT);
    gpio_set_direction(US_ECHO_PIN, GPIO_MODE_INPUT);
    gpio_set_level(US_TRIG_PIN, 0);

    // Peripherals
    gpio_set_direction(LIGHT_PIN, GPIO_MODE_OUTPUT);
    gpio_set_direction(HORN_PIN, GPIO_MODE_OUTPUT);
    gpio_set_level(LIGHT_PIN, 0);
    gpio_set_level(HORN_PIN, 0);
}

float sensor_get_distance(void) {
    gpio_set_level(US_TRIG_PIN, 0);
    ets_delay_us(2);
    gpio_set_level(US_TRIG_PIN, 1);
    ets_delay_us(10);
    gpio_set_level(US_TRIG_PIN, 0);

    // Wait for Echo High
    int timeout = 20000; // 20ms
    while (gpio_get_level(US_ECHO_PIN) == 0 && timeout > 0) {
        ets_delay_us(1);
        timeout--;
    }
    
    if (timeout == 0) return -1;

    int64_t start = esp_timer_get_time();
    
    // Wait for Echo Low
    timeout = 20000; // 20ms
    while (gpio_get_level(US_ECHO_PIN) == 1 && timeout > 0) {
        ets_delay_us(1);
        timeout--;
    }
    
    int64_t end = esp_timer_get_time();
    
    if (timeout == 0) return -1;

    float distance = (end - start) * 0.034 / 2;
    return distance;
}

void sensor_set_light(bool on) {
    gpio_set_level(LIGHT_PIN, on ? 1 : 0);
}

void sensor_set_horn(bool on) {
    gpio_set_level(HORN_PIN, on ? 1 : 0);
}
