#ifndef BLE_HRM_H
#define BLE_HRM_H

#include <stdint.h>
#include <stdbool.h>

// BLE Heart Rate Measurement Structure
typedef struct {
    uint16_t heart_rate;
    bool sensor_contact;
    uint16_t energy_expanded;
    // RR intervals could be added but skipping for simplicity
} hrm_data_t;

// Callback type for when HR data is received
typedef void (*ble_hrm_callback_t)(uint16_t hr_value);

/**
 * @brief Initialize BLE Heart Rate Client (and/or Server)
 * @param callback Function to be called when HR is updated
 */
void ble_hrm_init(ble_hrm_callback_t callback);

/**
 * @brief Scan and connect to a BLE Heart Rate Sensor
 */
void ble_hrm_start_scan(void);

#endif // BLE_HRM_H
