#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c.h"
#include "esp_log.h"
#include "esp_err.h"
#include "pca9685.h"

static const char *TAG = "pca9685";

#define SERVO_MIN_PULSE     102 // 0.5ms for 0 degree (102/4096 * 20ms = 0.5ms)
#define SERVO_MAX_PULSE     512 // 2.5ms for 180 degree (512/4096 * 20ms = 2.5ms)
#define SERVO_MAX_DEGREE    180

static esp_err_t i2c_master_init(void)
{
    int i2c_master_port = I2C_MASTER_NUM;

    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = I2C_MASTER_SDA_IO,
        .scl_io_num = I2C_MASTER_SCL_IO,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_MASTER_FREQ_HZ,
    };

    i2c_param_config(i2c_master_port, &conf);

    return i2c_driver_install(i2c_master_port, conf.mode, I2C_MASTER_RX_BUF_DISABLE, I2C_MASTER_TX_BUF_DISABLE, 0);
}

static esp_err_t pca9685_write_byte(uint8_t reg, uint8_t data)
{
    uint8_t write_buf[2] = {reg, data};
    return i2c_master_write_to_device(I2C_MASTER_NUM, PCA9685_ADDR, write_buf, sizeof(write_buf), I2C_MASTER_TIMEOUT_MS / portTICK_PERIOD_MS);
}

static esp_err_t pca9685_read_byte(uint8_t reg, uint8_t *data)
{
    return i2c_master_write_read_device(I2C_MASTER_NUM, PCA9685_ADDR, &reg, 1, data, 1, I2C_MASTER_TIMEOUT_MS / portTICK_PERIOD_MS);
}

esp_err_t pca9685_init(void)
{
    esp_err_t err = i2c_master_init();
    if (err != ESP_OK) return err;

    // Reset
    err = pca9685_write_byte(PCA9685_MODE1, 0x00);
    if (err != ESP_OK) return err;
    
    // Set frequency to 50Hz for servos
    err = pca9685_set_pwm_freq(50);
    if (err != ESP_OK) return err;
    
    ESP_LOGI(TAG, "PCA9685 Initialized");
    return ESP_OK;
}

esp_err_t pca9685_set_pwm_freq(float freq_hz)
{
    float prescaleval = 25000000;
    prescaleval /= 4096;
    prescaleval /= freq_hz;
    prescaleval -= 1;
    uint8_t prescale = (uint8_t)floor(prescaleval + 0.5);

    uint8_t oldmode;
    esp_err_t err;
    err = pca9685_read_byte(PCA9685_MODE1, &oldmode);
    if (err != ESP_OK) return err;

    uint8_t newmode = (oldmode & 0x7F) | 0x10; // sleep
    err = pca9685_write_byte(PCA9685_MODE1, newmode); // go to sleep
    if (err != ESP_OK) return err;

    err = pca9685_write_byte(PCA9685_PRESCALE, prescale); // set prescale
    if (err != ESP_OK) return err;

    err = pca9685_write_byte(PCA9685_MODE1, oldmode);
    if (err != ESP_OK) return err;

    vTaskDelay(5 / portTICK_PERIOD_MS);
    
    err = pca9685_write_byte(PCA9685_MODE1, oldmode | 0xa1); 
    if (err != ESP_OK) return err;

    return ESP_OK;
}

esp_err_t pca9685_set_pwm(uint8_t channel, uint16_t on, uint16_t off)
{
    uint8_t data[5];
    data[0] = PCA9685_LED0_ON_L + 4 * channel;
    data[1] = on & 0xFF;
    data[2] = on >> 8;
    data[3] = off & 0xFF;
    data[4] = off >> 8;
    return i2c_master_write_to_device(I2C_MASTER_NUM, PCA9685_ADDR, data, 5, I2C_MASTER_TIMEOUT_MS / portTICK_PERIOD_MS);
}

esp_err_t pca9685_stop_servo(uint8_t channel)
{
    // Set OFF bit 12 (0x1000) to force output LOW (Logic 0)
    // ON bit 12 should be 0.
    return pca9685_set_pwm(channel, 0, 4096); 
}

esp_err_t pca9685_set_servo_angle(uint8_t channel, float angle)
{
    if (angle < 0) angle = 0;
    if (angle > SERVO_MAX_DEGREE) angle = SERVO_MAX_DEGREE;

    // Map angle to pulse length
    // map(angle, 0, 180, SERVO_MIN, SERVO_MAX);
    int pulse = (int)(SERVO_MIN_PULSE + (angle * (SERVO_MAX_PULSE - SERVO_MIN_PULSE) / SERVO_MAX_DEGREE));
    
    return pca9685_set_pwm(channel, 0, pulse);
}
