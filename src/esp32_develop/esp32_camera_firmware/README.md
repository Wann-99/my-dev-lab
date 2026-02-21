# ESP32-Camera Firmware (OV3660 Edition)

This project is a custom firmware for the ESP32-CAM board equipped with an OV3660 sensor.
It connects to WiFi and streams video over HTTP.

## Hardware
- **Board**: ESP32-CAM (AI-Thinker or compatible)
- **Sensor**: OV3660 (3MP)
- **Pins**: Standard AI-Thinker pinout (see `main/camera_pins.h`)
- **Status LED**: Red LED (GPIO 33) - Blinks when connecting, Solid when connected.

## Configuration
1. **Menuconfig**:
   - Run `idf.py menuconfig` to configure:
     - **Camera Configuration**: Select Board Type (Default: AI-Thinker).
     - **WiFi Configuration**: Set SSID and Password.

2. **Manual Configuration (Optional)**:
   - You can also edit `main/wifi_app.h` or `sdkconfig.defaults` if you prefer not to use menuconfig.

## Features
- **WiFi Station Mode**: Connects to existing WiFi network.
- **MJPEG Stream**: High-performance video streaming at `/stream`.
- **Status API**: JSON status at `/status`.
- **OV3660 Support**: Optimized settings for 3MP sensor.

## Build & Flash

```bash
# 1. Set Target
idf.py set-target esp32

# 2. Configure (Optional)
idf.py menuconfig

# 3. Build
idf.py build

# 4. Flash (Replace COMx with your serial port)
idf.py -p COMx flash monitor
```

## Troubleshooting
- **Camera Init Failed**: Check power supply (needs 5V/2A stable). Check ribbon cable connection.
- **Brownout**: ESP32-CAM is power hungry. Ensure good USB cable and power source.
