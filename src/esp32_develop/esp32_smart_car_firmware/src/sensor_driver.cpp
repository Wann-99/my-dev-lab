#include "sensor_driver.h"

void SensorDriver::begin() {
    pinMode(US_TRIG_PIN, OUTPUT);
    pinMode(US_ECHO_PIN, INPUT);
    
    pinMode(LIGHT_PIN, OUTPUT);
    pinMode(HORN_PIN, OUTPUT);
    
    digitalWrite(US_TRIG_PIN, LOW);
    digitalWrite(LIGHT_PIN, LOW);
    digitalWrite(HORN_PIN, LOW);
}

float SensorDriver::getDistance() {
    digitalWrite(US_TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(US_TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(US_TRIG_PIN, LOW);

    // Timeout 30ms (approx 5m)
    long duration = pulseIn(US_ECHO_PIN, HIGH, 30000);
    
    if (duration == 0) return -1; // Timeout or error
    
    float distance = duration * 0.034 / 2;
    return distance;
}

void SensorDriver::setLight(bool on) {
    digitalWrite(LIGHT_PIN, on ? HIGH : LOW);
}

void SensorDriver::setHorn(bool on) {
    digitalWrite(HORN_PIN, on ? HIGH : LOW);
}
