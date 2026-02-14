#ifndef SERVO_DRIVER_H
#define SERVO_DRIVER_H

#include <Arduino.h>
#include <Adafruit_PWMServoDriver.h>
#include "config.h"

class ServoDriver {
public:
    void begin();
    void setAngle(uint8_t channel, uint8_t angle); // 0-180

private:
    Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();
    
    // Pulse width settings (approximate for SG90)
    const uint16_t USMIN = 500;
    const uint16_t USMAX = 2500;
    const uint16_t SERVO_FREQ = 50;
};

#endif
