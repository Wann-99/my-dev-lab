# ESP32-S3 Smart Car Firmware (ESP-IDF Version)

This project is designed for **Espressif-IDE** (Eclipse based) or command-line ESP-IDF.
Target: **ESP32-S3 N16R8** (16MB Flash, 8MB Octal PSRAM).

## Directory Structure
- `main/`: Source code
  - `main.c`: Main logic
  - `motor_driver.c`: Motor control (LEDC PWM)
  - `servo_driver.c`: Servo control (I2C PCA9685)
  - `sensor_driver.c`: Ultrasonic & GPIO
  - `wifi_server.c`: WiFi AP + WebSocket Server
- `partitions.csv`: Custom partition table for 16MB Flash
- `sdkconfig.defaults`: Default configuration for S3 N16R8

## How to Build & Flash

### Using Espressif-IDE
1. **Import Project**: File -> Import -> Espressif -> Existing IDF Project.
2. Select the `esp32_smart_car_idf` folder.
3. **Build**: Project -> Build Project.
4. **Flash**: Select target port and click Run.

### Using Command Line
1. Open ESP-IDF Terminal.
2. Navigate to project folder:
   ```bash
   cd esp32_smart_car_idf
   ```
3. Set Target:
   ```bash
   idf.py set-target esp32s3
   ```
4. Build and Flash:
   ```bash
   idf.py build flash monitor
   ```

## Configuration
- **WiFi SSID**: `ESP32_Car_IDF`
- **Password**: `12345678`
- **WebSocket Port**: `81`

## Pinout
Defined in `main/config.h`:
- Motor PWM: 14, 4, 7, 17
- Motor Dir: 21/13, 5/6, 15/16, 18/8
- I2C (Servo): SDA 11, SCL 12
- Ultrasonic: Trig 9, Echo 10
