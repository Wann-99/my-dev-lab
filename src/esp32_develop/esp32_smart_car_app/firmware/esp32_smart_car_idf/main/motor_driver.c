#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "esp_log.h"
#include "esp_err.h"
#include "motor_driver.h"
#include "encoder_driver.h"
#include "pid_ctrl.h"
#include "smc_ctrl.h"
#include <math.h>

static const char *TAG = "motor_driver";

// Motor Speed State
static int target_speeds[4] = {0, 0, 0, 0}; // Target pulses per interval
static int current_pwm[4] = {0, 0, 0, 0};
static int g_max_speed = 1023; // Max PWM duty
static int g_ramp_step = 50; 
static float g_steering_factor = 1.0f;

// Control Strategy
#define CTRL_STRATEGY_PID 0
#define CTRL_STRATEGY_SMC 1
static int g_ctrl_strategy = CTRL_STRATEGY_SMC; // Default to Sliding Mode Control

// Controllers
static pid_ctrl_t pid_m1, pid_m2, pid_m3, pid_m4;
static smc_ctrl_t smc_m1, smc_m2, smc_m3, smc_m4;
static encoder_t enc_m1, enc_m2, enc_m3, enc_m4;

// N20 Motor Specs
#define N20_GEAR_RATIO 30   
#define N20_ENCODER_PPR 7   
// Total counts per output shaft revolution = PPR * GearRatio * 4 (Quadrature) = 840
// Max Speed @ 12V ~300RPM -> 5 RPS -> 4200 counts/sec -> 210 counts/50ms

// --- Adaptive Control Parameters ---

#define PID_BASE_KP 1.5f
#define PID_BASE_KI 0.5f
#define PID_BASE_KD 0.1f

#define SMC_BASE_K_SW 200.0f
#define SMC_BASE_K_P 1.0f
#define SMC_BASE_BOUNDARY 50.0f

// PID Base & Adaptive Limits
static float g_pid_kp = PID_BASE_KP;
static float g_pid_ki = PID_BASE_KI;
static float g_pid_kd = PID_BASE_KD;

#define PID_LOW_SPEED_THRESHOLD 50.0f // counts/50ms
#define PID_BOOST_KP 2.5f
#define PID_BOOST_KI 0.8f

// SMC Base & Adaptive Limits
static float g_smc_k_sw = SMC_BASE_K_SW;
static float g_smc_k_p = SMC_BASE_K_P;
static float g_smc_boundary = SMC_BASE_BOUNDARY;

#define SMC_LOW_SPEED_K_SW 300.0f // Higher switching gain for stiction
#define SMC_HIGH_SPEED_K_SW 150.0f // Lower switching gain to reduce chatter

#define SMC_STEADY_BOUNDARY 80.0f // Wider boundary when steady to reduce chatter
#define SMC_TRANSIENT_BOUNDARY 30.0f // Narrower boundary when tracking fast changes

// Encoder Pins
#define M1_ENC_A 39
#define M1_ENC_B 40
#define M2_ENC_A 41
#define M2_ENC_B 42
#define M3_ENC_A 43
#define M3_ENC_B 44
#define M4_ENC_A 45
#define M4_ENC_B 46

// Motor Pins
#define M1_PWM_PIN 14
#define M1_IN1_PIN 21 
#define M1_IN2_PIN 13
#define M1_LEDC_CHANNEL LEDC_CHANNEL_0

#define M2_PWM_PIN 4
#define M2_IN1_PIN 5
#define M2_IN2_PIN 6 
#define M2_LEDC_CHANNEL LEDC_CHANNEL_1

#define M3_PWM_PIN 7 
#define M3_IN1_PIN 15
#define M3_IN2_PIN 16
#define M3_LEDC_CHANNEL LEDC_CHANNEL_2

#define M4_PWM_PIN 17
#define M4_IN1_PIN 18
#define M4_IN2_PIN 8 
#define M4_LEDC_CHANNEL LEDC_CHANNEL_3

#define LEDC_TIMER              LEDC_TIMER_0
#define LEDC_MODE               LEDC_LOW_SPEED_MODE
#define LEDC_DUTY_RES           LEDC_TIMER_10_BIT 
#define LEDC_FREQUENCY          20000 
#define MAX_PWM 1023 

static void update_motor_hardware(int motor_id, int pwm) {
    int in1_pin = -1;
    int in2_pin = -1;
    ledc_channel_t channel = LEDC_CHANNEL_0;

    switch (motor_id) {
        case 1: in1_pin = M1_IN1_PIN; in2_pin = M1_IN2_PIN; channel = M1_LEDC_CHANNEL; break;
        case 2: in1_pin = M2_IN1_PIN; in2_pin = M2_IN2_PIN; channel = M2_LEDC_CHANNEL; break;
        case 3: in1_pin = M3_IN1_PIN; in2_pin = M3_IN2_PIN; channel = M3_LEDC_CHANNEL; break;
        case 4: in1_pin = M4_IN1_PIN; in2_pin = M4_IN2_PIN; channel = M4_LEDC_CHANNEL; break;
        default: return;
    }

    int abs_pwm = abs(pwm);
    if (abs_pwm > MAX_PWM) abs_pwm = MAX_PWM;
    
    if (pwm > 0) {
        gpio_set_level(in1_pin, 1);
        gpio_set_level(in2_pin, 0);
    } else if (pwm < 0) {
        gpio_set_level(in1_pin, 0);
        gpio_set_level(in2_pin, 1);
    } else {
        gpio_set_level(in1_pin, 1);
        gpio_set_level(in2_pin, 1); // Brake
    }
    
    ledc_set_duty(LEDC_MODE, channel, abs_pwm);
    ledc_update_duty(LEDC_MODE, channel);
}

// Adaptive Parameter Update Logic
static void update_adaptive_params(int motor_idx, float target_speed, float measured_speed) {
    float abs_target = fabsf(target_speed);
    float error = fabsf(target_speed - measured_speed);
    
    if (g_ctrl_strategy == CTRL_STRATEGY_PID) {
        pid_ctrl_t *pid = NULL;
        switch(motor_idx) {
            case 0: pid = &pid_m1; break;
            case 1: pid = &pid_m2; break;
            case 2: pid = &pid_m3; break;
            case 3: pid = &pid_m4; break;
        }
        if (!pid) return;

        float kp = g_pid_kp;
        float ki = g_pid_ki;
        
        // Low speed boost (overcome friction)
        if (abs_target > 0 && abs_target < PID_LOW_SPEED_THRESHOLD) {
            kp = PID_BOOST_KP;
            ki = PID_BOOST_KI;
        }
        
        // Error boost (if stuck)
        if (error > 50.0f) {
            kp += 0.5f; 
        }

        pid_update_params(pid, kp, ki, g_pid_kd);

    } else { // SMC
        smc_ctrl_t *smc = NULL;
        switch(motor_idx) {
            case 0: smc = &smc_m1; break;
            case 1: smc = &smc_m2; break;
            case 2: smc = &smc_m3; break;
            case 3: smc = &smc_m4; break;
        }
        if (!smc) return;

        float k_sw = g_smc_k_sw;
        float boundary = g_smc_boundary;

        // Gain Scheduling based on Speed
        if (abs_target > 0 && abs_target < PID_LOW_SPEED_THRESHOLD) {
            k_sw = SMC_LOW_SPEED_K_SW;
        } else if (abs_target > 200.0f) {
            k_sw = SMC_HIGH_SPEED_K_SW;
        }

        // Boundary Adaptation based on Stability
        if (error < 20.0f) {
            boundary = SMC_STEADY_BOUNDARY; // Widen to reduce chatter
        } else {
            boundary = SMC_TRANSIENT_BOUNDARY; // Narrow for tracking
        }

        smc_update_params(smc, k_sw, g_smc_k_p, boundary);
    }
}

static void motor_control_task(void *pvParameters) {
    const int loop_interval_ms = 50; // 20Hz
    int64_t last_count[4] = {0};
    
    while (1) {
        // Read Encoders
        int64_t curr_count[4];
        curr_count[0] = encoder_get_count(&enc_m1);
        curr_count[1] = encoder_get_count(&enc_m2);
        curr_count[2] = encoder_get_count(&enc_m3);
        curr_count[3] = encoder_get_count(&enc_m4);
        
        // Calculate Speed (Pulses per interval)
        float measured_speed[4];
        for(int i=0; i<4; i++) {
            measured_speed[i] = (float)(curr_count[i] - last_count[i]);
            last_count[i] = curr_count[i];
        }

        float pwm_out[4];

        for(int i=0; i<4; i++) {
            // Run Adaptive Logic
            update_adaptive_params(i, (float)target_speeds[i], measured_speed[i]);

            if (g_ctrl_strategy == CTRL_STRATEGY_SMC) {
                smc_ctrl_t *smc = NULL;
                if(i==0) smc=&smc_m1; else if(i==1) smc=&smc_m2; else if(i==2) smc=&smc_m3; else smc=&smc_m4;
                
                pwm_out[i] = smc_compute(smc, (float)target_speeds[i], measured_speed[i]);
            } else {
                pid_ctrl_t *pid = NULL;
                if(i==0) pid=&pid_m1; else if(i==1) pid=&pid_m2; else if(i==2) pid=&pid_m3; else pid=&pid_m4;
                
                pwm_out[i] = pid_compute(pid, (float)target_speeds[i], measured_speed[i]);
            }
        }
        
        // Apply Output
        for(int i=0; i<4; i++) {
            current_pwm[i] = (int)pwm_out[i];
            update_motor_hardware(i+1, current_pwm[i]);
        }
        
        vTaskDelay(pdMS_TO_TICKS(loop_interval_ms));
    }
}

void motor_set_speed(int motor_id, int speed) {
    if (motor_id < 1 || motor_id > 4) return;
    
    // Scale factor: 210 (Max N20 count/50ms) / 1023 (Max Speed Input) ~= 0.2
    // Using 0.5 to allow for overdrive/higher voltage supply scenarios
    float target_scale = 0.5f; 
    int target = (int)(speed * target_scale);

    target_speeds[motor_id - 1] = target;
}

void motor_init(void) {
    ESP_LOGI(TAG, "Initializing Motors with %s Control...", (g_ctrl_strategy == CTRL_STRATEGY_SMC) ? "SMC" : "PID");
    
    // Init Hardware (PWM & GPIO)
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_MODE,
        .timer_num        = LEDC_TIMER,
        .duty_resolution  = LEDC_DUTY_RES,
        .freq_hz          = LEDC_FREQUENCY,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ESP_ERROR_CHECK(ledc_timer_config(&ledc_timer));

    ledc_channel_config_t ledc_channel[4] = {
        {.speed_mode = LEDC_MODE, .channel = M1_LEDC_CHANNEL, .timer_sel = LEDC_TIMER, .intr_type = LEDC_INTR_DISABLE, .gpio_num = M1_PWM_PIN, .duty = 0, .hpoint = 0},
        {.speed_mode = LEDC_MODE, .channel = M2_LEDC_CHANNEL, .timer_sel = LEDC_TIMER, .intr_type = LEDC_INTR_DISABLE, .gpio_num = M2_PWM_PIN, .duty = 0, .hpoint = 0},
        {.speed_mode = LEDC_MODE, .channel = M3_LEDC_CHANNEL, .timer_sel = LEDC_TIMER, .intr_type = LEDC_INTR_DISABLE, .gpio_num = M3_PWM_PIN, .duty = 0, .hpoint = 0},
        {.speed_mode = LEDC_MODE, .channel = M4_LEDC_CHANNEL, .timer_sel = LEDC_TIMER, .intr_type = LEDC_INTR_DISABLE, .gpio_num = M4_PWM_PIN, .duty = 0, .hpoint = 0},
    };
    for (int i = 0; i < 4; i++) ESP_ERROR_CHECK(ledc_channel_config(&ledc_channel[i]));

    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = ((1ULL<<M1_IN1_PIN) | (1ULL<<M1_IN2_PIN) | (1ULL<<M2_IN1_PIN) | (1ULL<<M2_IN2_PIN) | (1ULL<<M3_IN1_PIN) | (1ULL<<M3_IN2_PIN) | (1ULL<<M4_IN1_PIN) | (1ULL<<M4_IN2_PIN));
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    // Init Encoders
    encoder_init(&enc_m1, 1, M1_ENC_A, M1_ENC_B);
    encoder_init(&enc_m2, 2, M2_ENC_A, M2_ENC_B);
    encoder_init(&enc_m3, 3, M3_ENC_A, M3_ENC_B);
    encoder_init(&enc_m4, 4, M4_ENC_A, M4_ENC_B);

    // Init PID
    pid_init(&pid_m1, PID_BASE_KP, PID_BASE_KI, PID_BASE_KD, -MAX_PWM, MAX_PWM);
    pid_init(&pid_m2, PID_BASE_KP, PID_BASE_KI, PID_BASE_KD, -MAX_PWM, MAX_PWM);
    pid_init(&pid_m3, PID_BASE_KP, PID_BASE_KI, PID_BASE_KD, -MAX_PWM, MAX_PWM);
    pid_init(&pid_m4, PID_BASE_KP, PID_BASE_KI, PID_BASE_KD, -MAX_PWM, MAX_PWM);

    // Init SMC
    smc_init(&smc_m1, SMC_BASE_K_SW, SMC_BASE_K_P, SMC_BASE_BOUNDARY, -MAX_PWM, MAX_PWM);
    smc_init(&smc_m2, SMC_BASE_K_SW, SMC_BASE_K_P, SMC_BASE_BOUNDARY, -MAX_PWM, MAX_PWM);
    smc_init(&smc_m3, SMC_BASE_K_SW, SMC_BASE_K_P, SMC_BASE_BOUNDARY, -MAX_PWM, MAX_PWM);
    smc_init(&smc_m4, SMC_BASE_K_SW, SMC_BASE_K_P, SMC_BASE_BOUNDARY, -MAX_PWM, MAX_PWM);

    // Start Control Task
    xTaskCreate(motor_control_task, "motor_control_task", 4096, NULL, 5, NULL);
    ESP_LOGI(TAG, "Motor Control Loop Started");
}

void motor_stop(void) {
    target_speeds[0] = 0;
    target_speeds[1] = 0;
    target_speeds[2] = 0;
    target_speeds[3] = 0;
    
    pid_reset(&pid_m1);
    pid_reset(&pid_m2);
    pid_reset(&pid_m3);
    pid_reset(&pid_m4);
    
    smc_m1.prev_error = 0;
    smc_m2.prev_error = 0;
    smc_m3.prev_error = 0;
    smc_m4.prev_error = 0;

    update_motor_hardware(1, 0);
    update_motor_hardware(2, 0);
    update_motor_hardware(3, 0);
    update_motor_hardware(4, 0);
}

void move_car(float vx, float vy, float vw) {
    vw *= g_steering_factor;

    float fl = vx + vy + vw; // M1
    float fr = vx - vy - vw; // M2
    float rl = vx - vy + vw; // M3
    float rr = vx + vy - vw; // M4

    float max_val = fabs(fl);
    if (fabs(fr) > max_val) max_val = fabs(fr);
    if (fabs(rl) > max_val) max_val = fabs(rl);
    if (fabs(rr) > max_val) max_val = fabs(rr);

    if (max_val > 1.0f) {
        fl /= max_val;
        fr /= max_val;
        rl /= max_val;
        rr /= max_val;
    }

    // Map to g_max_speed
    int m1 = (int)(fl * g_max_speed);
    int m2 = (int)(fr * g_max_speed);
    int m3 = (int)(rl * g_max_speed);
    int m4 = (int)(rr * g_max_speed);

    motor_set_speed(1, m1);
    motor_set_speed(2, m2);
    motor_set_speed(3, m3);
    motor_set_speed(4, m4);
}

void motor_set_max_speed(int speed) {
    if (speed < 0) speed = 0;
    if (speed > 1023) speed = 1023;
    g_max_speed = speed;
}

int motor_get_max_speed(void) {
    return g_max_speed;
}

void motor_set_ramp_step(int step) {
    g_ramp_step = step;
}

void motor_set_steering_factor(float factor) {
    if (factor < 0.1f) factor = 0.1f;
    if (factor > 2.0f) factor = 2.0f;
    g_steering_factor = factor;
}

// 0 = PID, 1 = SMC
void motor_set_control_strategy(int strategy) {
    if (strategy == 0 || strategy == 1) {
        g_ctrl_strategy = strategy;
        ESP_LOGI(TAG, "Switched to %s Control", (strategy == 0) ? "PID" : "SMC");
    }
}

void motor_set_pid_params(float kp, float ki, float kd) {
    g_pid_kp = kp;
    g_pid_ki = ki;
    g_pid_kd = kd;
    ESP_LOGI(TAG, "PID Tuned: P=%.2f, I=%.2f, D=%.2f", kp, ki, kd);
}

void motor_set_smc_params(float k_sw, float k_p, float boundary) {
    g_smc_k_sw = k_sw;
    g_smc_k_p = k_p;
    g_smc_boundary = boundary;
    ESP_LOGI(TAG, "SMC Tuned: K_SW=%.2f, K_P=%.2f, Boundary=%.2f", k_sw, k_p, boundary);
}
