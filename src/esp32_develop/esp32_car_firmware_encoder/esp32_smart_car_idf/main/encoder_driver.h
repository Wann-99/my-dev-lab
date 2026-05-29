#pragma once

#include "driver/gpio.h"
#include "driver/pulse_cnt.h"

#ifdef __cplusplus
extern "C" {
#endif

// Encoder Configuration
#define ENCODER_HIGH_LIMIT 1000
#define ENCODER_LOW_LIMIT -1000

typedef struct {
    int motor_id;
    int pin_a;
    int pin_b;
    pcnt_unit_handle_t pcnt_unit;
    pcnt_channel_handle_t pcnt_chan_a;
    pcnt_channel_handle_t pcnt_chan_b;
    int64_t accum_count;
} encoder_t;

/**
 * @brief Initialize encoder for a motor
 * 
 * @param encoder Pointer to encoder structure
 * @param motor_id Motor ID (1-4)
 * @param pin_a GPIO pin for Phase A
 * @param pin_b GPIO pin for Phase B
 * @return esp_err_t ESP_OK on success
 */
esp_err_t encoder_init(encoder_t *encoder, int motor_id, int pin_a, int pin_b);

/**
 * @brief Get current pulse count from encoder (accumulated)
 * 
 * @param encoder Pointer to encoder structure
 * @return int64_t Total pulse count
 */
int64_t encoder_get_count(encoder_t *encoder);

/**
 * @brief Reset encoder count
 * 
 * @param encoder Pointer to encoder structure
 */
void encoder_reset(encoder_t *encoder);

#ifdef __cplusplus
}
#endif
