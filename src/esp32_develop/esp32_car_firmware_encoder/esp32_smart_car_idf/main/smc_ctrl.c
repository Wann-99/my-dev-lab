#include "smc_ctrl.h"
#include <math.h>

void smc_init(smc_ctrl_t *smc, float k_sw, float k_p, float boundary, float out_min, float out_max) {
    smc->k_sw = k_sw;       // Switching gain (robustness)
    smc->k_p = k_p;         // Proportional gain (reaching speed)
    smc->boundary = boundary; // Boundary layer thickness (reduce chattering)
    smc->out_min = out_min;
    smc->out_max = out_max;
    smc->prev_error = 0;
}

void smc_update_params(smc_ctrl_t *smc, float k_sw, float k_p, float boundary) {
    smc->k_sw = k_sw;
    smc->k_p = k_p;
    smc->boundary = boundary;
}

float smc_compute(smc_ctrl_t *smc, float setpoint, float measured) {
    float error = setpoint - measured;
    
    // Sliding Surface (s = e) for simple tracking
    // For better performance, s = c*e + e_dot could be used, but requires clean derivative.
    // Here we use a Reaching Law approach: u = Kp*e + Ksw*sat(s/phi)
    
    float s = error;
    
    // Saturation function to reduce chattering
    float sign_s;
    if (s > smc->boundary) {
        sign_s = 1.0f;
    } else if (s < -smc->boundary) {
        sign_s = -1.0f;
    } else {
        // Linear region inside boundary layer
        sign_s = s / smc->boundary;
    }

    // Control Law
    // u = Kp * e + Ksw * sign(s)
    // This is equivalent to a high-gain P-controller inside boundary, and constant switching outside.
    float output = (smc->k_p * error) + (smc->k_sw * sign_s);

    // Feedforward (Optional, if we knew model)
    // output += setpoint * KF; 

    // Clamp output
    if (output > smc->out_max) {
        output = smc->out_max;
    } else if (output < smc->out_min) {
        output = smc->out_min;
    }

    smc->prev_error = error;

    return output;
}
