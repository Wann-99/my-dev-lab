# ESP32 Smart Car Firmware

This project is the firmware for the ESP32 Smart Car, based on the provided circuit diagram and protocol.

## Hardware Requirements
- ESP32-S3 (N16R8)
- 4x DC Motors with L298N Drivers
- PCA9685 Servo Driver
- HC-SR04 Ultrasonic Sensor
- Mecanum Wheels (recommended for full omnidirectional control)

## Software Dependencies
- PlatformIO (recommended) or Arduino IDE
- Libraries (automatically installed by PlatformIO):
  - ArduinoJson
  - WebSockets
  - Adafruit PWM Servo Driver Library

## Setup
1. Open this folder in VS Code with PlatformIO extension.
2. Connect your ESP32-S3.
3. Upload the code (`PlatformIO: Upload`).

## WiFi Configuration
The car creates a WiFi Access Point:
- **SSID**: `ESP32_Car`
- **Password**: `12345678`
- **IP Address**: `192.168.4.1` (Default AP IP)
- **WebSocket Port**: `81`

## Features
- **Manual Control**: Supports omnidirectional movement (vx, vy, vw).
- **Auto Mode**: Basic obstacle avoidance using ultrasonic sensor.
- **Servo Control**: Pan/Tilt control for camera/sensor.
- **Status Feedback**: Reports distance and current mode.
