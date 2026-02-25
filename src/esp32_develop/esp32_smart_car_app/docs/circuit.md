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

### 5. Dual MCU Communication (Wireless)

The ESP32-S3 and ESP32-CAM communicate wirelessly using the **ESP-NOW** protocol. This replaces the physical UART wiring, making the build cleaner and more reliable.

- **Protocol**: ESP-NOW (Point-to-Point)
- **Channel**: Dynamically synced with WiFi (2.4GHz)
- **Functions**:
  - S3 sends WiFi credentials to CAM for automatic synchronization.
  - S3 sends camera controls (Flash LED, quality settings).
  - CAM sends status updates and responses.

> **Note**: No physical data wires are required between S3 and CAM. They only need to share a common Ground (GND) if powered from different sources, but since they share the battery/L298N power rail, even that is handled by the power wiring.

## ESP32-S3 Pinout (DevKit)

- **Power**: 5V (USB or Battery) and GND.
- **Battery Monitor (ADC)**: GPIO 1.
- **Light / Flash**: GPIO 2.
- **Horn / Buzzer**: GPIO 3.
- **USB Serial / Log**: GPIO 43 (TX), GPIO 44 (RX).
- **I2C**: GPIO 11 (SDA), GPIO 12 (SCL) - Used for PCA9685 Servo Controller.
- **Encoders**: 
  - M1: 39/40
  - M2: 41/42
  - M3: 43/44 (Note: This conflicts with USB Serial Log!)
  - M4: 45/46

## ESP32-CAM Pinout (AI-Thinker)

- **Power**: 5V (from Battery/L298N) and GND.
- **Vision**: All camera pins are fixed by internal connection.
- **Flash LED**: GPIO 4 (Controlled via Wireless command).
- **Status LED**: GPIO 33 (Active Low).

## Power Wiring

1. **L298N 12V**: Connect to Battery (+)
2. **L298N GND**: Connect to Battery (-) AND **ESP32 GND**
3. **ESP32 5V**: Can be powered from L298N 5V output (if 12V < 12V) or USB.
4. **PCA9685 V+**: Must connect to Battery (+) or 5V High Current source.

## Motor Direction Calibration

If wheels spin in wrong direction during test:
1. Swap IN1/IN2 wires for that motor.
2. OR change logic in `motor_driver.c`.
