# ESP32-CAM Firmware

This firmware provides:
1. **Self-Networking**: Creates a WiFi AP (`ESP32-CAM-Setup`) if it can't connect to a known network. Connect to it and configure your WiFi.
2. **mDNS**: Accessible via `http://esp32cam.local`.
3. **MJPEG Stream**: High quality, low latency stream at `http://esp32cam.local/stream`.

## Setup Instructions

1. **Install Arduino IDE**.
2. **Install ESP32 Board Support**:
   - Go to File > Preferences.
   - Add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json` to Additional Boards Manager URLs.
   - Go to Tools > Board > Boards Manager, search for `esp32` and install.
3. **Install Libraries**:
   - Sketch > Include Library > Manage Libraries.
   - Search for and install **WiFiManager** by *tzapu* (tested with version 2.0.17+).
4. **Select Board**:
   - Board: **AI Thinker ESP32-CAM**.
   - Upload Speed: **115200** (or faster if supported).
   - Partition Scheme: **Huge APP (3MB No OTA/1MB SPIFFS)** is recommended to fit everything.
5. **Flash**:
   - Connect GPIO 0 to GND.
   - Press Reset.
   - Click Upload.
   - Remove GPIO 0 from GND and press Reset.

## Usage

1. Power on the ESP32-CAM.
2. If it's the first time (or WiFi changed), look for WiFi network `ESP32-CAM-Setup` on your phone/PC.
3. Connect (Password: `password123`).
4. A captive portal should open (or go to `192.168.4.1`).
5. Select your WiFi and enter password.
6. The device will reboot and connect.
7. Use the App or go to `http://esp32cam.local/stream` in your browser.
