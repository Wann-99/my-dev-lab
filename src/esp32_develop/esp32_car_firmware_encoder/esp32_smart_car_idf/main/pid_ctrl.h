#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float kp;
    float ki;
    float kd;
    float prev_error;
    float integral;
    float out_min;
    float out_max;
} pid_ctrl_t;

/**
 * @brief Initialize PID controller
 * 
 * @param pid Pointer to PID structure
 * @param kp Proportional gain
 * @param ki Integral gain
 * @param kd Derivative gain
 * @param out_min Minimum output value
 * @param out_max Maximum output value
 */
void pid_init(pid_ctrl_t *pid, float kp, float ki, float kd, float out_min, float out_max);

/**
 * @brief Update PID parameters dynamically
 * 
 * @param pid Pointer to PID structure
 * @param kp Proportional gain
 * @param ki Integral gain
 * @param kd Derivative gain
 */
void pid_update_params(pid_ctrl_t *pid, float kp, float ki, float kd);

/**
 * @brief Compute PID output
 * 
 * @param pid Pointer to PID structure
 * @param setpoint Target value
 * @param measured Measured value
 * @return float Control output
 */
float pid_compute(pid_ctrl_t *pid, float setpoint, float measured);

/**
 * @brief Reset PID integral and error
 * 
 * @param pid Pointer to PID structure
 */
void pid_reset(pid_ctrl_t *pid);

#ifdef __cplusplus
}
#endif
