#pragma once

/**
 * @brief Handle car commands from JSON payload
 * 
 * @param payload JSON string
 */
void handle_car_command(const char* payload);

/**
 * @brief Set light state
 */
void set_light(int val);

/**
 * @brief Set horn state
 */
void set_horn(int val);
