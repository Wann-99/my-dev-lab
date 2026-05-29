#pragma once

#include <stdbool.h>

void motor_init(void);
void motor_stop(void);
void motor_set_speed(int motor_id, int speed);
void move_car(float vx, float vy, float vw);
void motor_set_max_speed(int speed);
int motor_get_max_speed(void);
void motor_set_ramp_step(int step);
void motor_set_steering_factor(float factor);

// New Control Parameters
void motor_set_deadzone(float deadzone);
void motor_set_lpf_alpha(float alpha);

// Control Strategy & Tuning
void motor_set_pid_params(float kp, float ki, float kd);

// Encoder-based in-place turn (closed-loop on wheel pulse counts).
// motor_turn_angle: rotate `angle_deg` degrees; dir = +1 (CW) / -1 (CCW).
// motor_turn_counts: rotate until average |delta pulses| per wheel reaches `counts`.
void motor_turn_angle(float angle_deg, int dir);
void motor_turn_counts(long long counts, int dir);
bool motor_turn_active(void);
void motor_turn_cancel(void);
