#ifndef CONFIG_H
#define CONFIG_H

// Motor 1 (Front Left)
#define M1_PWM_PIN 14
#define M1_IN1_PIN 21
#define M1_IN2_PIN 13

// Motor 2 (Front Right)
#define M2_PWM_PIN 4
#define M2_IN1_PIN 5
#define M2_IN2_PIN 6

// Motor 3 (Rear Left)
#define M3_PWM_PIN 7
#define M3_IN1_PIN 15
#define M3_IN2_PIN 16

// Motor 4 (Rear Right)
#define M4_PWM_PIN 17
#define M4_IN1_PIN 18
#define M4_IN2_PIN 8

// Ultrasonic Sensor
#define US_TRIG_PIN 9
#define US_ECHO_PIN 10

// I2C (Servo Driver PCA9685)
#define I2C_SDA_PIN 11
#define I2C_SCL_PIN 12
#define I2C_FREQ_HZ 100000

// Peripherals
#define LIGHT_PIN 2
#define HORN_PIN 3

// Network
#define WIFI_SSID "ESP32_Car_IDF"
#define WIFI_PASS "12345678"
#define WS_PORT 80

#endif
