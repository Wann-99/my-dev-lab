#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "esp_log.h"
#include "peripherals.h"

#define TAG "PERIPHERALS"

#define LED_GPIO        2
#define BUZZER_GPIO     4
#define BUTTON_GPIO     14 // Use GPIO 14 (Avoid GPIO 13/MTCK to prevent JTAG conflicts)

#define BUZZER_TIMER    LEDC_TIMER_0
#define BUZZER_MODE     LEDC_LOW_SPEED_MODE
#define BUZZER_CHANNEL  LEDC_CHANNEL_0
#define BUZZER_DUTY_RES LEDC_TIMER_13_BIT
#define BUZZER_FREQ     4000 // 4kHz

static void (*s_button_cb)(void) = NULL;

static void button_task(void* arg)
{
    int last_level = 1;
    for(;;) {
        int level = gpio_get_level(BUTTON_GPIO);
        
        if (last_level == 1 && level == 0) { // Falling edge (Pressed)
            // Debounce
            vTaskDelay(pdMS_TO_TICKS(50));
            if (gpio_get_level(BUTTON_GPIO) == 0) {
                 ESP_LOGI(TAG, "Button pressed");
                 if (s_button_cb) {
                     s_button_cb();
                 }
                 // Wait for release
                 while(gpio_get_level(BUTTON_GPIO) == 0) {
                     vTaskDelay(pdMS_TO_TICKS(50));
                 }
            }
        }
        last_level = level;
        vTaskDelay(pdMS_TO_TICKS(20)); // Polling interval
    }
}

void peripherals_init(void)
{
    // LED
    gpio_reset_pin(LED_GPIO);
    gpio_set_direction(LED_GPIO, GPIO_MODE_OUTPUT);
    gpio_set_level(LED_GPIO, 0);

    // Button
    gpio_reset_pin(BUTTON_GPIO);
    gpio_set_direction(BUTTON_GPIO, GPIO_MODE_INPUT);
    gpio_set_pull_mode(BUTTON_GPIO, GPIO_PULLUP_ONLY);
    // gpio_set_intr_type(BUTTON_GPIO, GPIO_INTR_NEGEDGE); // Disable Interrupts

    // Buzzer (LEDC)
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = BUZZER_MODE,
        .timer_num        = BUZZER_TIMER,
        .duty_resolution  = BUZZER_DUTY_RES,
        .freq_hz          = BUZZER_FREQ,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);

    ledc_channel_config_t ledc_channel = {
        .speed_mode     = BUZZER_MODE,
        .channel        = BUZZER_CHANNEL,
        .timer_sel      = BUZZER_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = BUZZER_GPIO,
        .duty           = 0, // 0%
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel);

    // Button Task
    // gpio_evt_queue = xQueueCreate(10, sizeof(uint32_t)); // Not needed for polling
    xTaskCreate(button_task, "button_task", 2048, NULL, 10, NULL);
    // gpio_install_isr_service(0); // Not needed
    // gpio_isr_handler_add(BUTTON_GPIO, gpio_isr_handler, (void*) BUTTON_GPIO); // Not needed
}

void led_set(bool on)
{
    gpio_set_level(LED_GPIO, on ? 1 : 0);
}

void buzzer_set(bool on)
{
    // 50% duty cycle for on, 0% for off
    uint32_t duty = on ? (1 << (13 - 1)) : 0;
    ledc_set_duty(BUZZER_MODE, BUZZER_CHANNEL, duty);
    ledc_update_duty(BUZZER_MODE, BUZZER_CHANNEL);
}

void buzzer_beep(int duration_ms)
{
    buzzer_set(true);
    vTaskDelay(pdMS_TO_TICKS(duration_ms));
    buzzer_set(false);
}

bool button_is_pressed(void)
{
    return gpio_get_level(BUTTON_GPIO) == 0;
}

void button_register_callback(void (*callback)(void))
{
    s_button_cb = callback;
}
