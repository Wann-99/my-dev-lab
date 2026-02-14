#include <Arduino.h>
#include "config.h"
#include "motor_driver.h"
#include "servo_driver.h"
#include "sensor_driver.h"
#include "web_server.h"

MotorDriver motor;
ServoDriver servo;
SensorDriver sensor;
CarWebServer server;

String currentMode = "manual";
unsigned long lastSensorTime = 0;
const long SENSOR_INTERVAL = 500; // 500ms

// Current movement state
float target_vx = 0;
float target_vy = 0;
float target_vw = 0;

void handleCommand(JsonDocument& doc) {
    const char* cmd = doc["cmd"];
    
    if (strcmp(cmd, "mode") == 0) {
        if (doc.containsKey("value")) {
            currentMode = doc["value"].as<String>();
            Serial.println("Mode changed to: " + currentMode);
            // Stop motors when switching modes
            motor.stop();
            target_vx = 0; target_vy = 0; target_vw = 0;
        }
    }
    else if (strcmp(cmd, "speed") == 0) {
        if (doc.containsKey("value")) {
            int speed = doc["value"];
            motor.setMaxSpeed(speed);
        }
    }
    else if (strcmp(cmd, "servo") == 0) {
        int id = doc["id"];
        int angle = doc["angle"];
        servo.setAngle(id, angle);
    }
    else if (strcmp(cmd, "move") == 0) {
        if (currentMode == "manual") {
            target_vx = doc["vx"];
            target_vy = doc["vy"];
            target_vw = doc["vw"];
            
            // Map -1.0~1.0 to -255~255
            int16_t pwm_vx = target_vx * 255;
            int16_t pwm_vy = target_vy * 255;
            int16_t pwm_vw = target_vw * 255;
            
            motor.setSpeed(pwm_vx, pwm_vy, pwm_vw);
        }
    }
}

void setup() {
    Serial.begin(115200);
    
    // Init drivers
    motor.begin();
    servo.begin();
    sensor.begin();
    
    // Init Server
    server.setCommandCallback(handleCommand);
    server.begin();
    
    Serial.println("System Ready");
}

void loop() {
    server.loop();
    
    unsigned long currentMillis = millis();
    
    // Sensor Update Loop
    if (currentMillis - lastSensorTime >= SENSOR_INTERVAL) {
        lastSensorTime = currentMillis;
        
        float dist = sensor.getDistance();
        server.sendStatus(dist, currentMode);
        
        // Auto Mode Logic
        if (currentMode == "auto") {
            if (dist > 0 && dist < 30.0) {
                // Obstacle detected (< 30cm)
                // Stop and Turn
                motor.setSpeed(0, 0, 150); // Rotate
                sensor.setHorn(true); // Beep
            } else {
                // Clear path
                motor.setSpeed(100, 0, 0); // Move forward slowly
                sensor.setHorn(false);
            }
        }
    }
}
