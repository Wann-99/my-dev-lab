#ifndef MOTOR_DRIVER_H
#define MOTOR_DRIVER_H

#include <Arduino.h>
#include "config.h"

class MotorDriver {
public:
    void begin();
    void setSpeed(int16_t vx, int16_t vy, int16_t vw); // Inputs: -255 to 255
    void stop();
    void setMaxSpeed(uint8_t speed);

private:
    uint8_t _maxSpeed = 255;
    
    void setMotor(int pinPWM, int pinIN1, int pinIN2, int speed);
};

#endif
