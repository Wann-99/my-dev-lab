#pragma once

void motor_init(void);
void motor_stop(void);
void motor_set_speed(int motor_id, int speed);
void move_car(float vx, float vy, float vw);
void motor_set_max_speed(int speed);
int motor_get_max_speed(void);
void motor_set_ramp_step(int step);
void motor_set_steering_factor(float factor);

// Control Strategy & Tuning
void motor_set_control_strategy(int strategy);
void motor_set_pid_params(float kp, float ki, float kd);
void motor_set_smc_params(float k_sw, float k_p, float boundary);
