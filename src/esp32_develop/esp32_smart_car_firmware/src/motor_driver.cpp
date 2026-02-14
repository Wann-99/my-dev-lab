#include "motor_driver.h"

void MotorDriver::begin() {
    pinMode(M1_PWM_PIN, OUTPUT);
    pinMode(M1_IN1_PIN, OUTPUT);
    pinMode(M1_IN2_PIN, OUTPUT);

    pinMode(M2_PWM_PIN, OUTPUT);
    pinMode(M2_IN1_PIN, OUTPUT);
    pinMode(M2_IN2_PIN, OUTPUT);

    pinMode(M3_PWM_PIN, OUTPUT);
    pinMode(M3_IN1_PIN, OUTPUT);
    pinMode(M3_IN2_PIN, OUTPUT);

    pinMode(M4_PWM_PIN, OUTPUT);
    pinMode(M4_IN1_PIN, OUTPUT);
    pinMode(M4_IN2_PIN, OUTPUT);
    
    stop();
}

void MotorDriver::setMaxSpeed(uint8_t speed) {
    _maxSpeed = speed;
}

void MotorDriver::stop() {
    setMotor(M1_PWM_PIN, M1_IN1_PIN, M1_IN2_PIN, 0);
    setMotor(M2_PWM_PIN, M2_IN1_PIN, M2_IN2_PIN, 0);
    setMotor(M3_PWM_PIN, M3_IN1_PIN, M3_IN2_PIN, 0);
    setMotor(M4_PWM_PIN, M4_IN1_PIN, M4_IN2_PIN, 0);
}

// Mecanum kinematics
// vx: Forward/Back
// vy: Left/Right
// vw: Rotate
void MotorDriver::setSpeed(int16_t vx, int16_t vy, int16_t vw) {
    // Kinematic formulas for Mecanum wheels
    // Depending on the wheel orientation (X vs O configuration), signs might vary.
    // Assuming standard "O" configuration:
    // FL = y + x + r
    // FR = y - x - r
    // RL = y - x + r
    // RR = y + x - r
    
    int16_t speed1 = vx + vy + vw; // FL
    int16_t speed2 = vx - vy - vw; // FR
    int16_t speed3 = vx - vy + vw; // RL
    int16_t speed4 = vx + vy - vw; // RR

    // Normalize if exceeding max speed
    int16_t max_val = max(abs(speed1), max(abs(speed2), max(abs(speed3), abs(speed4))));
    if (max_val > _maxSpeed) {
        float scale = (float)_maxSpeed / max_val;
        speed1 *= scale;
        speed2 *= scale;
        speed3 *= scale;
        speed4 *= scale;
    }
    
    setMotor(M1_PWM_PIN, M1_IN1_PIN, M1_IN2_PIN, speed1);
    setMotor(M2_PWM_PIN, M2_IN1_PIN, M2_IN2_PIN, speed2);
    setMotor(M3_PWM_PIN, M3_IN1_PIN, M3_IN2_PIN, speed3);
    setMotor(M4_PWM_PIN, M4_IN1_PIN, M4_IN2_PIN, speed4);
}

void MotorDriver::setMotor(int pinPWM, int pinIN1, int pinIN2, int speed) {
    // Clip speed
    if (speed > 255) speed = 255;
    if (speed < -255) speed = -255;

    if (speed > 0) {
        digitalWrite(pinIN1, HIGH);
        digitalWrite(pinIN2, LOW);
        analogWrite(pinPWM, speed);
    } else if (speed < 0) {
        digitalWrite(pinIN1, LOW);
        digitalWrite(pinIN2, HIGH);
        analogWrite(pinPWM, -speed);
    } else {
        digitalWrite(pinIN1, LOW);
        digitalWrite(pinIN2, LOW);
        analogWrite(pinPWM, 0);
    }
}
