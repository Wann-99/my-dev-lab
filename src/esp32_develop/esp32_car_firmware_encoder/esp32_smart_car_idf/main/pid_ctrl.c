#include "pid_ctrl.h"

void pid_init(pid_ctrl_t *pid, float kp, float ki, float kd, float out_min, float out_max) {
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
    pid->prev_error = 0;
    pid->integral = 0;
    pid->out_min = out_min;
    pid->out_max = out_max;
}

void pid_update_params(pid_ctrl_t *pid, float kp, float ki, float kd) {
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
}

float pid_compute(pid_ctrl_t *pid, float setpoint, float measured) {
    float error = setpoint - measured;
    
    // Proportional term
    float p_out = pid->kp * error;

    // Integral term with anti-windup
    pid->integral += error;
    float i_out = pid->ki * pid->integral;

    // Derivative term
    float derivative = error - pid->prev_error;
    float d_out = pid->kd * derivative;

    // Total output
    float output = p_out + i_out + d_out;

    // Clamp output
    if (output > pid->out_max) {
        output = pid->out_max;
        // Anti-windup: Clamp integral only if it's contributing to saturation
        if (pid->ki != 0 && error > 0) {
            pid->integral -= error; 
        }
    } else if (output < pid->out_min) {
        output = pid->out_min;
        if (pid->ki != 0 && error < 0) {
            pid->integral -= error;
        }
    }

    pid->prev_error = error;

    return output;
}

void pid_reset(pid_ctrl_t *pid) {
    pid->prev_error = 0;
    pid->integral = 0;
}
