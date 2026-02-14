#ifndef MOTOR_DRIVER_H
#define MOTOR_DRIVER_H

#include <stdint.h>
#include "driver/ledc.h"
#include "driver/gpio.h"

// Define LEDC Timer and Channels
#define LEDC_TIMER              LEDC_TIMER_0
#define LEDC_MODE               LEDC_LOW_SPEED_MODE
#define LEDC_OUTPUT_IO_1        M1_PWM_PIN
#define LEDC_OUTPUT_IO_2        M2_PWM_PIN
#define LEDC_OUTPUT_IO_3        M3_PWM_PIN
#define LEDC_OUTPUT_IO_4        M4_PWM_PIN
#define LEDC_DUTY_RES           LEDC_TIMER_8_BIT // Set duty resolution to 8 bits
#define LEDC_FREQUENCY          5000 // Frequency in Hertz. Set frequency at 5 kHz

void motor_init(void);
void motor_set_speed(float vx, float vy, float vw);
void motor_stop(void);
void motor_set_max_speed(uint8_t speed);

#endif
