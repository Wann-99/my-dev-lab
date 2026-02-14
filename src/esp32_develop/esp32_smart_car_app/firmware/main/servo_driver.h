#ifndef SERVO_DRIVER_H
#define SERVO_DRIVER_H

#include <stdint.h>
#include "driver/i2c.h"

// I2C Configuration
#define I2C_MASTER_NUM      I2C_NUM_0
#define I2C_MASTER_FREQ_HZ  100000
#define I2C_MASTER_TX_BUF_DISABLE 0
#define I2C_MASTER_RX_BUF_DISABLE 0

// PCA9685 Registers
#define PCA9685_ADDR        0x40
#define PCA9685_MODE1       0x00
#define PCA9685_PRESCALE    0xFE
#define LED0_ON_L           0x06

void servo_init(void);
void servo_set_angle(uint8_t channel, uint8_t angle);
void servo_stop(uint8_t channel);

#endif
