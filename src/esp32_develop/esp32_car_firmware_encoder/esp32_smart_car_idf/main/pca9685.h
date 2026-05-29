#pragma once
#include <stdint.h>
#include "esp_err.h"

// I2C Configuration
#define I2C_MASTER_SCL_IO           12      /*!< GPIO number used for I2C master clock (Safe Pin) */
#define I2C_MASTER_SDA_IO           11      /*!< GPIO number used for I2C master data  (Safe Pin) */
#define I2C_MASTER_NUM              0       /*!< I2C master i2c port number, the number of i2c peripheral interfaces available will depend on the chip */
#define I2C_MASTER_FREQ_HZ          100000  /*!< I2C master clock frequency */
#define I2C_MASTER_TX_BUF_DISABLE   0       /*!< I2C master doesn't need buffer */
#define I2C_MASTER_RX_BUF_DISABLE   0       /*!< I2C master doesn't need buffer */
#define I2C_MASTER_TIMEOUT_MS       1000

// PCA9685 Configuration
#define PCA9685_ADDR                0x40    /*!< Default I2C address */
#define PCA9685_MODE1               0x00
#define PCA9685_PRESCALE            0xFE
#define PCA9685_LED0_ON_L           0x06

esp_err_t pca9685_init(void);
esp_err_t pca9685_set_pwm_freq(float freq_hz);
esp_err_t pca9685_set_pwm(uint8_t channel, uint16_t on, uint16_t off);
esp_err_t pca9685_stop_servo(uint8_t channel); // Stop signal (Low Level)
esp_err_t pca9685_set_servo_angle(uint8_t channel, float angle);
