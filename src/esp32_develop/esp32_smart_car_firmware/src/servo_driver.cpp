#include "servo_driver.h"
#include <Wire.h>

void ServoDriver::begin() {
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    pwm.begin();
    pwm.setOscillatorFrequency(27000000);
    pwm.setPWMFreq(SERVO_FREQ);
    
    // Set initial position (90 degrees)
    setAngle(SERVO_CH_HORIZONTAL, 90);
    setAngle(SERVO_CH_VERTICAL, 90);
}

void ServoDriver::setAngle(uint8_t channel, uint8_t angle) {
    if (angle > 180) angle = 180;
    
    // Map angle to microseconds
    uint16_t us = map(angle, 0, 180, USMIN, USMAX);
    
    // Convert to 12-bit value (0-4096)
    // 1000000 / 50 = 20000 us per cycle
    // 4096 ticks per 20000 us
    // ticks = us * 4096 / 20000 = us * 0.2048
    // Adafruit library has helper writeMicroseconds
    pwm.writeMicroseconds(channel, us);
}
