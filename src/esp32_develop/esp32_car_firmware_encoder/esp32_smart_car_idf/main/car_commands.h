#ifndef CAR_COMMANDS_H
#define CAR_COMMANDS_H

#include "esp_err.h"

/**
 * @brief Process a JSON command string for the car
 * 
 * @param json_data The JSON string received
 * @param response_buffer Buffer to store response (if any)
 * @param response_len Length of the response buffer
 * @return esp_err_t 
 */
esp_err_t handle_car_command(const char *json_data, char *response_buffer, size_t response_len);

#endif // CAR_COMMANDS_H
