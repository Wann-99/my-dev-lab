# ESP32 Smart Car Circuit Diagram

## Pin Definitions (ESP32-S3 N16R8 Safe)

**IMPORTANT**: Do NOT use GPIO 26-37 on ESP32-S3 N16R8 as they are used for Flash/PSRAM.
**IMPORTANT**: Do NOT use GPIO 19-20 if using native USB.

### 1. Motor Driver (L298N x 2)

| Motor | Function | ESP32 Pin |
| :--- | :--- | :--- |
| **M1 (Front Left)** | PWM | **GPIO 14** |
| | IN1 | **GPIO 21** |
| | IN2 | **GPIO 13** |
| **M2 (Front Right)** | PWM | **GPIO 4** |
| | IN1 | **GPIO 5** |
| | IN2 | **GPIO 6** |
| **M3 (Rear Left)** | PWM | **GPIO 7** |
| | IN1 | **GPIO 15** |
| | IN2 | **GPIO 16** |
| **M4 (Rear Right)** | PWM | **GPIO 17** |
| | IN1 | **GPIO 18** |
| | IN2 | **GPIO 8** |

### 2. Ultrasonic Sensor (HC-SR04)

| Pin | ESP32 Pin |
| :--- | :--- |
| VCC | 5V |
| Trig | **GPIO 9** |
| Echo | **GPIO 10** |
| GND | GND |

### 3. Servo Driver (PCA9685)

| Pin | ESP32 Pin |
| :--- | :--- |
| SDA | **GPIO 11** |
| SCL | **GPIO 12** |
| VCC | 3.3V / 5V |
| GND | GND |
| **V+** | **5V+ (External Power)** |

### 4. Peripherals (Light & Horn)

| Component | Pin | ESP32 Pin | Note |
| :--- | :--- | :--- | :--- |
| **Car Light** | Signal / Anode (+) | **GPIO 2** | Use resistor (220Ω-1kΩ) if connecting LED directly |
| | GND / Cathode (-) | GND | |
| **Horn** | Signal / I/O | **GPIO 3** | Active Buzzer Module recommended (High Level Trigger) |
| | VCC | 3.3V / 5V | |
| | GND | GND | |

## Power Wiring

1. **L298N 12V**: Connect to Battery (+)
2. **L298N GND**: Connect to Battery (-) AND **ESP32 GND**
3. **ESP32 5V**: Can be powered from L298N 5V output (if 12V < 12V) or USB.
4. **PCA9685 V+**: Must connect to Battery (+) or 5V High Current source.

## Motor Direction Calibration

If wheels spin in wrong direction during test:
1. Swap IN1/IN2 wires for that motor.
2. OR change logic in `motor_driver.c`.
