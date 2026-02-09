#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "esp_log.h"
#include "esp_err.h"
#include "motor_driver.h"
#include <math.h>

static const char *TAG = "motor_driver";

// Motor 1
#define M1_PWM_PIN 14
#define M1_IN1_PIN 21 // Safe pin (Replaces 2/27)
#define M1_IN2_PIN 13
#define M1_LEDC_CHANNEL LEDC_CHANNEL_0

// Motor 2
#define M2_PWM_PIN 4
#define M2_IN1_PIN 5
#define M2_IN2_PIN 6  // Safe on S3
#define M2_LEDC_CHANNEL LEDC_CHANNEL_1

// Motor 3
#define M3_PWM_PIN 7  // Safe on S3
#define M3_IN1_PIN 15
#define M3_IN2_PIN 16
#define M3_LEDC_CHANNEL LEDC_CHANNEL_2

// Motor 4
#define M4_PWM_PIN 17
#define M4_IN1_PIN 18
#define M4_IN2_PIN 8  // Safe on S3
#define M4_LEDC_CHANNEL LEDC_CHANNEL_3

#define LEDC_TIMER              LEDC_TIMER_0
#define LEDC_MODE               LEDC_LOW_SPEED_MODE
// #define LEDC_OUTPUT_IO       (5) // Removed: Unused and conflicts with M2_IN1 definition
#define LEDC_DUTY_RES           LEDC_TIMER_10_BIT // Increased resolution for better control
#define LEDC_FREQUENCY          20000 // 20kHz for N20 motors (reduces noise/improves torque)

#define MAX_SPEED 1023 // Max duty for 10-bit resolution
#define MIN_DUTY 600   // Min duty to overcome static friction (User reported <50% stall)

void motor_set_speed(int motor_id, int speed) {
    int in1_pin = -1;
    int in2_pin = -1;
    ledc_channel_t channel = LEDC_CHANNEL_0;

    switch (motor_id) {
        case 1:
            in1_pin = M1_IN1_PIN; in2_pin = M1_IN2_PIN; channel = M1_LEDC_CHANNEL;
            break;
        case 2:
            in1_pin = M2_IN1_PIN; in2_pin = M2_IN2_PIN; channel = M2_LEDC_CHANNEL;
            break;
        case 3:
            in1_pin = M3_IN1_PIN; in2_pin = M3_IN2_PIN; channel = M3_LEDC_CHANNEL;
            break;
        case 4:
            in1_pin = M4_IN1_PIN; in2_pin = M4_IN2_PIN; channel = M4_LEDC_CHANNEL;
            break;
        default:
            return;
    }

    // Input Clamp
    if (speed > 1023) speed = 1023;
    if (speed < -1023) speed = -1023;

    int abs_speed = abs(speed);
    int final_duty = 0;

    // Dead Zone Mapping: Map [1, 1023] -> [MIN_DUTY, 1023]
    if (abs_speed > 10) { // Threshold to allow full stop
        final_duty = MIN_DUTY + (abs_speed * (MAX_SPEED - MIN_DUTY) / MAX_SPEED);
    }

    if (speed > 0) {
        gpio_set_level(in1_pin, 1);
        gpio_set_level(in2_pin, 0);
        ledc_set_duty(LEDC_MODE, channel, final_duty);
        ledc_update_duty(LEDC_MODE, channel);
    } else if (speed < 0) {
        gpio_set_level(in1_pin, 0);
        gpio_set_level(in2_pin, 1);
        ledc_set_duty(LEDC_MODE, channel, final_duty);
        ledc_update_duty(LEDC_MODE, channel);
    } else {
        gpio_set_level(in1_pin, 0);
        gpio_set_level(in2_pin, 0);
        ledc_set_duty(LEDC_MODE, channel, 0);
        ledc_update_duty(LEDC_MODE, channel);
    }
}

void motor_init(void) {
    ESP_LOGI(TAG, "Initializing Motors...");
    ESP_LOGI(TAG, "M1: PWM=%d, IN1=%d, IN2=%d", M1_PWM_PIN, M1_IN1_PIN, M1_IN2_PIN);
    ESP_LOGI(TAG, "M2: PWM=%d, IN1=%d, IN2=%d", M2_PWM_PIN, M2_IN1_PIN, M2_IN2_PIN);
    ESP_LOGI(TAG, "M3: PWM=%d, IN1=%d, IN2=%d", M3_PWM_PIN, M3_IN1_PIN, M3_IN2_PIN);
    ESP_LOGI(TAG, "M4: PWM=%d, IN1=%d, IN2=%d", M4_PWM_PIN, M4_IN1_PIN, M4_IN2_PIN);

    // Configure LEDC Timer
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_MODE,
        .timer_num        = LEDC_TIMER,
        .duty_resolution  = LEDC_DUTY_RES,
        .freq_hz          = LEDC_FREQUENCY,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ESP_ERROR_CHECK(ledc_timer_config(&ledc_timer));

    // Configure LEDC Channels
    ledc_channel_config_t ledc_channel[4] = {
        {
            .speed_mode     = LEDC_MODE,
            .channel        = M1_LEDC_CHANNEL,
            .timer_sel      = LEDC_TIMER,
            .intr_type      = LEDC_INTR_DISABLE,
            .gpio_num       = M1_PWM_PIN,
            .duty           = 0,
            .hpoint         = 0
        },
        {
            .speed_mode     = LEDC_MODE,
            .channel        = M2_LEDC_CHANNEL,
            .timer_sel      = LEDC_TIMER,
            .intr_type      = LEDC_INTR_DISABLE,
            .gpio_num       = M2_PWM_PIN,
            .duty           = 0,
            .hpoint         = 0
        },
        {
            .speed_mode     = LEDC_MODE,
            .channel        = M3_LEDC_CHANNEL,
            .timer_sel      = LEDC_TIMER,
            .intr_type      = LEDC_INTR_DISABLE,
            .gpio_num       = M3_PWM_PIN,
            .duty           = 0,
            .hpoint         = 0
        },
        {
            .speed_mode     = LEDC_MODE,
            .channel        = M4_LEDC_CHANNEL,
            .timer_sel      = LEDC_TIMER,
            .intr_type      = LEDC_INTR_DISABLE,
            .gpio_num       = M4_PWM_PIN,
            .duty           = 0,
            .hpoint         = 0
        },
    };

    for (int i = 0; i < 4; i++) {
        ESP_ERROR_CHECK(ledc_channel_config(&ledc_channel[i]));
    }

    // Configure GPIOs for Direction
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = ((1ULL<<M1_IN1_PIN) | (1ULL<<M1_IN2_PIN) |
                            (1ULL<<M2_IN1_PIN) | (1ULL<<M2_IN2_PIN) |
                            (1ULL<<M3_IN1_PIN) | (1ULL<<M3_IN2_PIN) |
                            (1ULL<<M4_IN1_PIN) | (1ULL<<M4_IN2_PIN));
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    ESP_LOGI(TAG, "Motors initialized");
}

void motor_stop(void) {
    motor_set_speed(1, 0);
    motor_set_speed(2, 0);
    motor_set_speed(3, 0);
    motor_set_speed(4, 0);
}

void move_car(float vx, float vy, float vw) {
    // vx: forward/back, vy: left/right, vw: rotation
    // Standard Mecanum Wheel Kinematics (X-Configuration)
    // M1 = Front Left  (FL)
    // M2 = Front Right (FR)
    // M3 = Rear Left   (RL)
    // M4 = Rear Right  (RR)
    
    // Forward (+X): All wheels +
    // Right (+Y): FL+, FR-, RL-, RR+
    // Rotate Right/CW (+W): Left+, Right- (FL+, FR-, RL+, RR-)
    
    float fl = vx + vy + vw; // M1
    float fr = vx - vy - vw; // M2
    float rl = vx - vy + vw; // M3
    float rr = vx + vy - vw; // M4

    // 1. Find the maximum absolute speed to normalize
    float max_val = fabs(fl);
    if (fabs(fr) > max_val) max_val = fabs(fr);
    if (fabs(rl) > max_val) max_val = fabs(rl);
    if (fabs(rr) > max_val) max_val = fabs(rr);

    // 2. Normalize if any motor exceeds 1.0 (Preserves direction ratio)
    if (max_val > 1.0f) {
        fl /= max_val;
        fr /= max_val;
        rl /= max_val;
        rr /= max_val;
    }

    // 3. Convert to integer speed
    int m1 = (int)(fl * MAX_SPEED);
    int m2 = (int)(fr * MAX_SPEED);
    int m3 = (int)(rl * MAX_SPEED);
    int m4 = (int)(rr * MAX_SPEED);

    ESP_LOGI(TAG, "Move Car: vx=%.2f, vy=%.2f, vw=%.2f -> M1:%d, M2:%d, M3:%d, M4:%d", vx, vy, vw, m1, m2, m3, m4);

    motor_set_speed(1, m1);
    motor_set_speed(2, m2);
    motor_set_speed(3, m3);
    motor_set_speed(4, m4);
}
