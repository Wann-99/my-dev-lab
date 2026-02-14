#include "motor_driver.h"
#include "config.h"
#include <math.h>

static uint8_t max_speed = 255;

// Helper to set individual motor
// speed: -255 to 255
static void set_single_motor(ledc_channel_t channel, int in1, int in2, int speed) {
    if (speed > 255) speed = 255;
    if (speed < -255) speed = -255;

    if (speed > 0) {
        gpio_set_level(in1, 1);
        gpio_set_level(in2, 0);
    } else if (speed < 0) {
        gpio_set_level(in1, 0);
        gpio_set_level(in2, 1);
        speed = -speed;
    } else {
        gpio_set_level(in1, 0);
        gpio_set_level(in2, 0);
        speed = 0;
    }

    ledc_set_duty(LEDC_MODE, channel, speed);
    ledc_update_duty(LEDC_MODE, channel);
}

void motor_init(void) {
    // 1. Setup PWM (LEDC) Timer
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_MODE,
        .timer_num        = LEDC_TIMER,
        .duty_resolution  = LEDC_DUTY_RES,
        .freq_hz          = LEDC_FREQUENCY,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);

    // 2. Setup PWM Channels
    // Channel 0 -> M1
    ledc_channel_config_t ledc_channel_0 = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL_0,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = M1_PWM_PIN,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_0);

    // Channel 1 -> M2
    ledc_channel_config_t ledc_channel_1 = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL_1,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = M2_PWM_PIN,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_1);

    // Channel 2 -> M3
    ledc_channel_config_t ledc_channel_2 = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL_2,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = M3_PWM_PIN,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_2);

    // Channel 3 -> M4
    ledc_channel_config_t ledc_channel_3 = {
        .speed_mode     = LEDC_MODE,
        .channel        = LEDC_CHANNEL_3,
        .timer_sel      = LEDC_TIMER,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = M4_PWM_PIN,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_3);

    // 3. Setup GPIO for Direction (IN1/IN2)
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = ((1ULL<<M1_IN1_PIN) | (1ULL<<M1_IN2_PIN) |
                            (1ULL<<M2_IN1_PIN) | (1ULL<<M2_IN2_PIN) |
                            (1ULL<<M3_IN1_PIN) | (1ULL<<M3_IN2_PIN) |
                            (1ULL<<M4_IN1_PIN) | (1ULL<<M4_IN2_PIN));
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    gpio_config(&io_conf);

    motor_stop();
}

void motor_stop(void) {
    set_single_motor(LEDC_CHANNEL_0, M1_IN1_PIN, M1_IN2_PIN, 0);
    set_single_motor(LEDC_CHANNEL_1, M2_IN1_PIN, M2_IN2_PIN, 0);
    set_single_motor(LEDC_CHANNEL_2, M3_IN1_PIN, M3_IN2_PIN, 0);
    set_single_motor(LEDC_CHANNEL_3, M4_IN1_PIN, M4_IN2_PIN, 0);
}

void motor_set_max_speed(uint8_t speed) {
    max_speed = speed;
}

void motor_set_speed(float vx, float vy, float vw) {
    // vx, vy, vw inputs are -1.0 to 1.0
    // Scale to max_speed
    
    float speed1 = vx + vy + vw; // FL
    float speed2 = vx - vy - vw; // FR
    float speed3 = vx - vy + vw; // RL
    float speed4 = vx + vy - vw; // RR

    // Normalize
    float max_val = 0.0f;
    if (fabs(speed1) > max_val) max_val = fabs(speed1);
    if (fabs(speed2) > max_val) max_val = fabs(speed2);
    if (fabs(speed3) > max_val) max_val = fabs(speed3);
    if (fabs(speed4) > max_val) max_val = fabs(speed4);

    if (max_val > 1.0f) {
        speed1 /= max_val;
        speed2 /= max_val;
        speed3 /= max_val;
        speed4 /= max_val;
    }

    int s1 = (int)(speed1 * max_speed);
    int s2 = (int)(speed2 * max_speed);
    int s3 = (int)(speed3 * max_speed);
    int s4 = (int)(speed4 * max_speed);

    set_single_motor(LEDC_CHANNEL_0, M1_IN1_PIN, M1_IN2_PIN, s1);
    set_single_motor(LEDC_CHANNEL_1, M2_IN1_PIN, M2_IN2_PIN, s2);
    set_single_motor(LEDC_CHANNEL_2, M3_IN1_PIN, M3_IN2_PIN, s3);
    set_single_motor(LEDC_CHANNEL_3, M4_IN1_PIN, M4_IN2_PIN, s4);
}
