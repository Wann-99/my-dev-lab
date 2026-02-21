#include "encoder_driver.h"
#include "esp_log.h"

static const char *TAG = "encoder_driver";

static bool pcnt_on_reach(pcnt_unit_handle_t unit, const pcnt_watch_event_data_t *edata, void *user_ctx)
{
    encoder_t *encoder = (encoder_t *)user_ctx;
    // Accumulate count based on watch event
    // When high limit reached, we add (HIGH_LIMIT - LOW_LIMIT) to accumulator?
    // Actually, simpler: just let it wrap and handle logic in get_count?
    // No, standard way is to clear and add to software accumulator.
    
    // For simplicity with IDF 5.x PCNT driver, we can use the callback to track overflows.
    // But for a car speed, 16-bit PCNT might overflow quickly.
    // Let's assume we read fast enough in the PID loop (e.g., every 50ms) and clear it.
    // However, to keep track of absolute position, we need accumulation.
    
    // NOTE: This is a simplified ISR context.
    return false;
}

esp_err_t encoder_init(encoder_t *encoder, int motor_id, int pin_a, int pin_b)
{
    encoder->motor_id = motor_id;
    encoder->pin_a = pin_a;
    encoder->pin_b = pin_b;
    encoder->accum_count = 0;

    ESP_LOGI(TAG, "Init Encoder M%d: A=%d, B=%d", motor_id, pin_a, pin_b);

    pcnt_unit_config_t unit_config = {
        .high_limit = ENCODER_HIGH_LIMIT,
        .low_limit = ENCODER_LOW_LIMIT,
    };
    ESP_ERROR_CHECK(pcnt_new_unit(&unit_config, &encoder->pcnt_unit));

    pcnt_glitch_filter_config_t filter_config = {
        .max_glitch_ns = 1000,
    };
    ESP_ERROR_CHECK(pcnt_unit_set_glitch_filter(encoder->pcnt_unit, &filter_config));

    pcnt_chan_config_t chan_a_config = {
        .edge_gpio_num = pin_a,
        .level_gpio_num = pin_b,
    };
    ESP_ERROR_CHECK(pcnt_new_channel(encoder->pcnt_unit, &chan_a_config, &encoder->pcnt_chan_a));

    pcnt_chan_config_t chan_b_config = {
        .edge_gpio_num = pin_b,
        .level_gpio_num = pin_a,
    };
    ESP_ERROR_CHECK(pcnt_new_channel(encoder->pcnt_unit, &chan_b_config, &encoder->pcnt_chan_b));

    // Quadrature decoding
    ESP_ERROR_CHECK(pcnt_channel_set_edge_action(encoder->pcnt_chan_a, PCNT_CHANNEL_EDGE_ACTION_DECREASE, PCNT_CHANNEL_EDGE_ACTION_INCREASE));
    ESP_ERROR_CHECK(pcnt_channel_set_level_action(encoder->pcnt_chan_a, PCNT_CHANNEL_LEVEL_ACTION_KEEP, PCNT_CHANNEL_LEVEL_ACTION_INVERSE));
    
    ESP_ERROR_CHECK(pcnt_channel_set_edge_action(encoder->pcnt_chan_b, PCNT_CHANNEL_EDGE_ACTION_INCREASE, PCNT_CHANNEL_EDGE_ACTION_DECREASE));
    ESP_ERROR_CHECK(pcnt_channel_set_level_action(encoder->pcnt_chan_b, PCNT_CHANNEL_LEVEL_ACTION_KEEP, PCNT_CHANNEL_LEVEL_ACTION_INVERSE));

    ESP_ERROR_CHECK(pcnt_unit_enable(encoder->pcnt_unit));
    ESP_ERROR_CHECK(pcnt_unit_clear_count(encoder->pcnt_unit));
    ESP_ERROR_CHECK(pcnt_unit_start(encoder->pcnt_unit));

    return ESP_OK;
}

int64_t encoder_get_count(encoder_t *encoder)
{
    int count = 0;
    pcnt_unit_get_count(encoder->pcnt_unit, &count);
    
    // For speed calculation, we usually read and clear.
    // But clearing might lose pulses if not careful.
    // Better to read absolute and diff.
    // However, 16-bit hardware counter wraps.
    // Since we are running PID loop frequently (e.g. 20Hz), 
    // the count won't overflow 16-bit range (approx +/- 32000) in 50ms unless motor is super fast.
    // (e.g. 3000RPM = 50 RPS. If encoder is 1000 PPR, that's 50000 pulses/sec. In 0.05s, that's 2500 pulses.)
    // So simple read and clear is safe enough for speed control.
    
    // To implement "read and clear" atomically:
    // pcnt_unit_clear_count() resets to 0.
    // But we need the value before clear.
    // There is a small window.
    // For robust implementation, we just return the raw count and let caller handle diff.
    // But caller needs to handle wrapping if we don't clear.
    // Let's use Read-Clear strategy for speed measurement simplicity.
    
    pcnt_unit_clear_count(encoder->pcnt_unit);
    return (int64_t)count; 
}

void encoder_reset(encoder_t *encoder)
{
    pcnt_unit_clear_count(encoder->pcnt_unit);
    encoder->accum_count = 0;
}
