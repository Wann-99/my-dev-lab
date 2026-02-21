#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float k_sw;      // Switching Gain (Magnitude of discontinuous term)
    float k_p;       // Proportional Gain (Reachability)
    float boundary;  // Boundary Layer Thickness (Chattering reduction)
    float prev_error;
    float out_min;
    float out_max;
} smc_ctrl_t;

/**
 * @brief Initialize Sliding Mode Controller
 * 
 * @param smc Pointer to SMC structure
 * @param k_sw Switching gain (Robustness against disturbances)
 * @param k_p Proportional gain (Performance)
 * @param boundary Boundary layer thickness (0.1 - 10.0 typical)
 * @param out_min Minimum output
 * @param out_max Maximum output
 */
void smc_init(smc_ctrl_t *smc, float k_sw, float k_p, float boundary, float out_min, float out_max);

/**
 * @brief Update SMC parameters dynamically
 * 
 * @param smc Pointer to SMC structure
 * @param k_sw Switching gain
 * @param k_p Proportional gain
 * @param boundary Boundary layer thickness
 */
void smc_update_params(smc_ctrl_t *smc, float k_sw, float k_p, float boundary);

/**
 * @brief Compute SMC output
 * 
 * @param smc Pointer to SMC structure
 * @param setpoint Target value
 * @param measured Measured value
 * @return float Control output
 */
float smc_compute(smc_ctrl_t *smc, float setpoint, float measured);

#ifdef __cplusplus
}
#endif
