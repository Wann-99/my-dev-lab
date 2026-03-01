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
#include <math.h>

static const char *TAG = "motor_driver";

// Motor Speed State
static int target_speeds[4] = {0, 0, 0, 0}; // Target pulses per interval
static int current_pwm[4] = {0, 0, 0, 0};
static int g_max_speed = 1023; // Max PWM duty
static float g_deadzone = 0.02f; 
static float g_lpf_alpha = 0.8f; 
static float last_v_fwd = 0.0f;
static float last_v_side = 0.0f;
static float last_v_rot = 0.0f;

// Control parameters
static int g_ramp_step = 10;
static float g_steering_factor = 1.0f;

// Controllers
static pid_ctrl_t pid_m1, pid_m2, pid_m3, pid_m4;
static encoder_t enc_m1, enc_m2, enc_m3, enc_m4;

// JGA-N20 Motor Specs
#define MOTOR_GEAR_RATIO 150   
#define MOTOR_ENCODER_PPR 7   
#define MOTOR_ENCODER_CPR (MOTOR_ENCODER_PPR * 4) // AB相四倍频
#define MOTOR_OUTPUT_CPR (MOTOR_ENCODER_CPR * MOTOR_GEAR_RATIO) // 减速后每转脉冲 = 28 * 150 = 4200 CPR
#define MOTOR_MAX_RPM 100.0f // 额定转速
#define MOTOR_MAX_RAD_PER_SEC (MOTOR_MAX_RPM * 2 * M_PI / 60.0f) // 10.47 rad/s
#define WHEEL_DIAMETER_MM 60.0f // 轮径
#define WHEEL_CIRCUMFERENCE_MM (WHEEL_DIAMETER_MM * M_PI) // 188.5mm
#define MAX_SPEED_MM_PER_SEC (WHEEL_CIRCUMFERENCE_MM * MOTOR_MAX_RPM / 60.0f) // 314mm/s

// Control loop parameters
#define CONTROL_LOOP_INTERVAL_MS 50 // 20Hz
#define COUNTS_PER_INTERVAL_MAX (MOTOR_OUTPUT_CPR * MOTOR_MAX_RPM / 60.0f * CONTROL_LOOP_INTERVAL_MS / 1000.0f) // 210 counts/50ms

// PID Control Parameters
#define PID_BASE_KP 1.5f
#define PID_BASE_KI 0.5f
#define PID_BASE_KD 0.1f

// PID Base & Adaptive Limits
static float g_pid_kp = PID_BASE_KP;
static float g_pid_ki = PID_BASE_KI;
static float g_pid_kd = PID_BASE_KD;

#define PID_LOW_SPEED_THRESHOLD 50.0f // counts/50ms
#define PID_BOOST_KP 2.5f
#define PID_BOOST_KI 0.8f

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

// Update all motors simultaneously for synchronized response
static void update_all_motors(int pwm1, int pwm2, int pwm3, int pwm4) {
    // First, set all GPIO directions and PWM duties
    // Motor 1
    if (pwm1 > 0) {
        gpio_set_level(M1_IN1_PIN, 1);
        gpio_set_level(M1_IN2_PIN, 0);
    } else if (pwm1 < 0) {
        gpio_set_level(M1_IN1_PIN, 0);
        gpio_set_level(M1_IN2_PIN, 1);
    }
    ledc_set_duty(LEDC_MODE, M1_LEDC_CHANNEL, abs(pwm1));
    
    // Motor 2
    if (pwm2 > 0) {
        gpio_set_level(M2_IN1_PIN, 1);
        gpio_set_level(M2_IN2_PIN, 0);
    } else if (pwm2 < 0) {
        gpio_set_level(M2_IN1_PIN, 0);
        gpio_set_level(M2_IN2_PIN, 1);
    }
    ledc_set_duty(LEDC_MODE, M2_LEDC_CHANNEL, abs(pwm2));
    
    // Motor 3
    if (pwm3 > 0) {
        gpio_set_level(M3_IN1_PIN, 1);
        gpio_set_level(M3_IN2_PIN, 0);
    } else if (pwm3 < 0) {
        gpio_set_level(M3_IN1_PIN, 0);
        gpio_set_level(M3_IN2_PIN, 1);
    }
    ledc_set_duty(LEDC_MODE, M3_LEDC_CHANNEL, abs(pwm3));
    
    // Motor 4
    if (pwm4 > 0) {
        gpio_set_level(M4_IN1_PIN, 1);
        gpio_set_level(M4_IN2_PIN, 0);
    } else if (pwm4 < 0) {
        gpio_set_level(M4_IN1_PIN, 0);
        gpio_set_level(M4_IN2_PIN, 1);
    }
    ledc_set_duty(LEDC_MODE, M4_LEDC_CHANNEL, abs(pwm4));
    
    // Update all PWM duties simultaneously
    ledc_update_duty(LEDC_MODE, M1_LEDC_CHANNEL);
    ledc_update_duty(LEDC_MODE, M2_LEDC_CHANNEL);
    ledc_update_duty(LEDC_MODE, M3_LEDC_CHANNEL);
    ledc_update_duty(LEDC_MODE, M4_LEDC_CHANNEL);
    
    // Handle braking for motors that need it
    bool need_braking = (pwm1 == 0 || pwm2 == 0 || pwm3 == 0 || pwm4 == 0);
    if (need_braking) {
        // Apply reverse pulse for braking
        if (pwm1 == 0) {
            gpio_set_level(M1_IN1_PIN, 0);
            gpio_set_level(M1_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M1_LEDC_CHANNEL, 300);
        }
        if (pwm2 == 0) {
            gpio_set_level(M2_IN1_PIN, 0);
            gpio_set_level(M2_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M2_LEDC_CHANNEL, 300);
        }
        if (pwm3 == 0) {
            gpio_set_level(M3_IN1_PIN, 0);
            gpio_set_level(M3_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M3_LEDC_CHANNEL, 300);
        }
        if (pwm4 == 0) {
            gpio_set_level(M4_IN1_PIN, 0);
            gpio_set_level(M4_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M4_LEDC_CHANNEL, 300);
        }
        
        // Update all braking PWM simultaneously
        ledc_update_duty(LEDC_MODE, M1_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M2_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M3_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M4_LEDC_CHANNEL);
        
        // Small delay for braking pulse
        vTaskDelay(pdMS_TO_TICKS(5));
        
        // Set to brake mode
        if (pwm1 == 0) {
            gpio_set_level(M1_IN1_PIN, 1);
            gpio_set_level(M1_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M1_LEDC_CHANNEL, 0);
        }
        if (pwm2 == 0) {
            gpio_set_level(M2_IN1_PIN, 1);
            gpio_set_level(M2_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M2_LEDC_CHANNEL, 0);
        }
        if (pwm3 == 0) {
            gpio_set_level(M3_IN1_PIN, 1);
            gpio_set_level(M3_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M3_LEDC_CHANNEL, 0);
        }
        if (pwm4 == 0) {
            gpio_set_level(M4_IN1_PIN, 1);
            gpio_set_level(M4_IN2_PIN, 1);
            ledc_set_duty(LEDC_MODE, M4_LEDC_CHANNEL, 0);
        }
        
        // Update all to brake mode simultaneously
        ledc_update_duty(LEDC_MODE, M1_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M2_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M3_LEDC_CHANNEL);
        ledc_update_duty(LEDC_MODE, M4_LEDC_CHANNEL);
    }
}

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
        ledc_set_duty(LEDC_MODE, channel, abs_pwm);
        ledc_update_duty(LEDC_MODE, channel);
    } else if (pwm < 0) {
        gpio_set_level(in1_pin, 0);
        gpio_set_level(in2_pin, 1);
        ledc_set_duty(LEDC_MODE, channel, abs_pwm);
        ledc_update_duty(LEDC_MODE, channel);
    } else {
        // Active braking: apply a short reverse pulse to quickly stop the motor
        // First, apply reverse voltage for a short time
        gpio_set_level(in1_pin, 0);
        gpio_set_level(in2_pin, 1);
        ledc_set_duty(LEDC_MODE, channel, 300); // Moderate braking power
        ledc_update_duty(LEDC_MODE, channel);
        // Small delay to allow the braking pulse to take effect
        vTaskDelay(pdMS_TO_TICKS(5));
        // Then set to brake mode
        gpio_set_level(in1_pin, 1);
        gpio_set_level(in2_pin, 1);
        ledc_set_duty(LEDC_MODE, channel, 0);
        ledc_update_duty(LEDC_MODE, channel);
    }
}

// Adaptive Parameter Update Logic
static void update_adaptive_params(int motor_idx, float target_speed, float measured_speed) {
    float abs_target = fabsf(target_speed);
    float error = fabsf(target_speed - measured_speed);
    
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
}

static void motor_control_task(void *pvParameters) {
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
            pid_ctrl_t *pid = NULL;
            if(i==0) pid=&pid_m1; else if(i==1) pid=&pid_m2; else if(i==2) pid=&pid_m3; else pid=&pid_m4;
            
            // Update adaptive parameters
            update_adaptive_params(i, (float)target_speeds[i], measured_speed[i]);
            
            // PID + Feedforward Control
            // Feedforward term: proportional to target speed
            float feedforward = target_speeds[i] * 0.5f; // Adjust feedforward gain as needed
            float pid_output = pid_compute(pid, (float)target_speeds[i], measured_speed[i]);
            pwm_out[i] = pid_output + feedforward;
        }
        
        // Apply Output
        for(int i=0; i<4; i++) {
            if (target_speeds[i] == 0) {
                // If target speed is 0, force PWM to 0 and reset PID
                current_pwm[i] = 0;
                // Reset PID controller to prevent integral windup
                if(i==0) pid_reset(&pid_m1);
                else if(i==1) pid_reset(&pid_m2);
                else if(i==2) pid_reset(&pid_m3);
                else pid_reset(&pid_m4);
            } else {
                current_pwm[i] = (int)pwm_out[i];
                // Clamp PWM output
                if (current_pwm[i] > g_max_speed) current_pwm[i] = g_max_speed;
                if (current_pwm[i] < -g_max_speed) current_pwm[i] = -g_max_speed;
            }
        }
        
        // Update all motors simultaneously for synchronized response
        update_all_motors(current_pwm[0], current_pwm[1], current_pwm[2], current_pwm[3]);
        
        vTaskDelay(pdMS_TO_TICKS(CONTROL_LOOP_INTERVAL_MS));
    }
}

void motor_set_speed(int motor_id, int speed) {
    if (motor_id < 1 || motor_id > 4) return;
    
    // Optimized speed mapping
    // 0: Stop
    // 1-1023: Non-linear mapping for better control
    int min_effective_speed = 10; // Minimum speed to overcome friction (micro movement)
    int max_speed = 210; // Maximum speed
    int target;
    
    if (speed == 0) {
        target = 0;
    } else {
        // Non-linear mapping for better low-speed control
        // Scale speed from 1-1023 to 0-1 range
        float normalized_speed = (speed - 1) / 1022.0f;
        // Use square root for better low-speed resolution
        float mapped_speed = sqrtf(normalized_speed);
        // Map to min_effective_speed to max_speed range
        target = min_effective_speed + (int)((max_speed - min_effective_speed) * mapped_speed);
    }

    target_speeds[motor_id - 1] = target;
    
    // Debug logging for motor speed setting
    if (speed != 0) {
        ESP_LOGI(TAG, "Motor %d speed set to %d, target %d", motor_id, speed, target);
    }
}

void motor_init(void) {
    ESP_LOGI(TAG, "Initializing Motors with PID+Feedforward Control...");
    
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

    update_motor_hardware(1, 0);
    update_motor_hardware(2, 0);
    update_motor_hardware(3, 0);
    update_motor_hardware(4, 0);
}

void motor_set_deadzone(float deadzone) {
    if (deadzone < 0.0f) deadzone = 0.0f;
    if (deadzone > 0.5f) deadzone = 0.5f;
    g_deadzone = deadzone;
}

void motor_set_lpf_alpha(float alpha) {
    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;
    g_lpf_alpha = alpha;
}

static float apply_deadzone(float input) {
    if (fabs(input) < g_deadzone) return 0.0f;
    return input;
}

static float low_pass_filter(float new_val, float old_val) {
    return g_lpf_alpha * new_val + (1.0f - g_lpf_alpha) * old_val;
}

void move_car(float vx, float vy, float vw) {
    // Map inputs to User's Kinematic Model naming
    // App sends: vx (Forward/Back), vy (Strafe), vw (Turn)
    // User Spec: Vy (Forward), Vx (Side), Vw (Turn)
    
    float v_fwd = vx; 
    float v_side = vy;
    float v_rot = vw;

    // Check if all inputs are zero (stop command)
    if (vx == 0 && vy == 0 && vw == 0) {
        // For stop command, directly set to zero without filtering
        v_fwd = 0.0f;
        v_side = 0.0f;
        v_rot = 0.0f;
    } else {
        // 1. Deadzone Processing
        v_fwd = apply_deadzone(v_fwd);
        v_side = apply_deadzone(v_side);
        v_rot = apply_deadzone(v_rot);

        // 2. Low Pass Filter
        v_fwd = low_pass_filter(v_fwd, last_v_fwd);
        v_side = low_pass_filter(v_side, last_v_side);
        v_rot = low_pass_filter(v_rot, last_v_rot);
    }
    
    last_v_fwd = v_fwd;
    last_v_side = v_side;
    last_v_rot = v_rot;

    // 3. Kinematic Model (Mecanum)
    // FL = Vy + Vx + Vw
    // FR = Vy - Vx - Vw
    // RL = Vy - Vx + Vw
    // RR = Vy + Vx - Vw
    
    float fl = v_fwd + v_side + v_rot;
    float fr = v_fwd - v_side - v_rot;
    float rl = v_fwd - v_side + v_rot;
    float rr = v_fwd + v_side - v_rot;
    
    // Debug logging for motor speeds
    if (v_fwd != 0 || v_side != 0 || v_rot != 0) {
        ESP_LOGI(TAG, "Move: vx=%.2f vy=%.2f vw=%.2f", vx, vy, vw);
        ESP_LOGI(TAG, "Motor speeds: FL=%.2f FR=%.2f RL=%.2f RR=%.2f", fl, fr, rl, rr);
    }

    // 4. Output Limiting / Normalization
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

    int m1 = (int)(fl * g_max_speed);
    int m2 = (int)(fr * g_max_speed);
    int m3 = (int)(rl * g_max_speed);
    int m4 = (int)(rr * g_max_speed);

    // Update all target speeds simultaneously
    target_speeds[0] = m1;
    target_speeds[1] = m2;
    target_speeds[2] = m3;
    target_speeds[3] = m4;
    
    // Debug logging for motor speeds
    if (v_fwd != 0 || v_side != 0 || v_rot != 0) {
        ESP_LOGI(TAG, "Motor speeds set: M1=%d M2=%d M3=%d M4=%d", m1, m2, m3, m4);
    }
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

void motor_set_pid_params(float kp, float ki, float kd) {
    g_pid_kp = kp;
    g_pid_ki = ki;
    g_pid_kd = kd;
    ESP_LOGI(TAG, "PID Tuned: P=%.2f, I=%.2f, D=%.2f", kp, ki, kd);
}
