#include "servo_driver.h"
#include "config.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <math.h>

static const char *TAG = "SERVO";

static esp_err_t write_byte(uint8_t reg, uint8_t data) {
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (PCA9685_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, reg, true);
    i2c_master_write_byte(cmd, data, true);
    i2c_master_stop(cmd);
    esp_err_t ret = i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
    return ret;
}

static uint8_t read_byte(uint8_t reg) {
    uint8_t data = 0;
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (PCA9685_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, reg, true);
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (PCA9685_ADDR << 1) | I2C_MASTER_READ, true);
    i2c_master_read_byte(cmd, &data, I2C_MASTER_LAST_NACK);
    i2c_master_stop(cmd);
    i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
    return data;
}

static void set_pwm_freq(float freq_hz) {
    float prescaleval = 25000000;
    prescaleval /= 4096;
    prescaleval /= freq_hz;
    prescaleval -= 1;
    uint8_t prescale = (uint8_t)(prescaleval + 0.5);

    uint8_t oldmode = read_byte(PCA9685_MODE1);
    uint8_t newmode = (oldmode & 0x7F) | 0x10; // sleep
    write_byte(PCA9685_MODE1, newmode); // go to sleep
    write_byte(PCA9685_PRESCALE, prescale); // set prescale
    write_byte(PCA9685_MODE1, oldmode);
    vTaskDelay(5 / portTICK_PERIOD_MS);
    write_byte(PCA9685_MODE1, oldmode | 0xa1); 
}

static void set_pwm(uint8_t channel, uint16_t on, uint16_t off) {
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, (PCA9685_ADDR << 1) | I2C_MASTER_WRITE, true);
    i2c_master_write_byte(cmd, LED0_ON_L + 4 * channel, true);
    i2c_master_write_byte(cmd, on & 0xFF, true);
    i2c_master_write_byte(cmd, on >> 8, true);
    i2c_master_write_byte(cmd, off & 0xFF, true);
    i2c_master_write_byte(cmd, off >> 8, true);
    i2c_master_stop(cmd);
    i2c_master_cmd_begin(I2C_MASTER_NUM, cmd, 1000 / portTICK_PERIOD_MS);
    i2c_cmd_link_delete(cmd);
}

void servo_init(void) {
    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = I2C_SDA_PIN,
        .scl_io_num = I2C_SCL_PIN,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_MASTER_FREQ_HZ,
    };
    
    i2c_param_config(I2C_MASTER_NUM, &conf);
    i2c_driver_install(I2C_MASTER_NUM, conf.mode, I2C_MASTER_RX_BUF_DISABLE, I2C_MASTER_TX_BUF_DISABLE, 0);

    write_byte(PCA9685_MODE1, 0x00);
    set_pwm_freq(50); // 50Hz for servo
    ESP_LOGI(TAG, "Servo Driver Initialized");
}

void servo_set_angle(uint8_t channel, uint8_t angle) {
    if (angle > 180) angle = 180;
    // Map 0-180 to pulse width 500-2500us
    // 50Hz = 20000us period
    // 4096 ticks per 20000us
    // tick = us * 4096 / 20000 = us * 0.2048
    
    uint16_t us = 500 + (angle * 2000 / 180);
    uint16_t off = (uint16_t)(us * 0.2048);
    
    set_pwm(channel, 0, off);
}

void servo_stop(uint8_t channel) {
    // Setting both ON and OFF to 0 turns the LED/PWM completely OFF
    set_pwm(channel, 0, 0);
}
