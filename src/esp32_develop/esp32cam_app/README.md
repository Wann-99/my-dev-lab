# ESP32-CAM 实时监控系统 (Flutter + ESP32)

一套完整的低延迟、高画质 ESP32-CAM 监控方案，包含自助配网、mDNS 本地域名解析、无线固件升级 (OTA) 以及配套的 Flutter APP。

## 🚀 主要特性

- **低延迟流媒体**：采用原生 `esp_http_server` 实现 MJPEG 流，配合 WiFi 功耗优化，延迟极低。
- **自助配网 (WiFiManager)**：无 WiFi 时自动开启 `ESP32-CAM-Setup` 热点，通过手机网页配置网络。
- **本地域名支持 (mDNS)**：支持通过 `esp32cam.local` 访问，无需固定 IP。
- **双端口隔离架构**：
  - **Port 80**: 视频流专用，保证高带宽。
  - **Port 8080**: 管理专用，处理 OTA 升级和网络重置，不被视频流阻塞。
- **无线升级 (OTA)**：支持浏览器网页上传固件及 Arduino IDE 无线烧录，带 LED 状态反馈。
- **网络切换**：APP 内一键重置 WiFi，设备自动进入配网模式。

---

## 🛠️ ESP32 端配置 (Arduino IDE)

### 1. 硬件准备
- ESP32-CAM 开发板 (建议带 PSRAM 版本)
- OV2640 摄像头模块

### 2. 依赖库
请在 Arduino 库管理器中安装：
- `WiFiManager` (by tzapu)
- `esp32` 开发板支持包 (建议版本 2.0.x)

### 3. 关键设置 (代码中已预设)
- **频率优化**：XCLK 设为 `10MHz` 以提高摄像头稳定性，解决 "Capture Failed" 报错。
- **功耗优化**：禁用 WiFi Power Saving (`WIFI_PS_NONE`)，将延迟从 200ms+ 降低至 <10ms。
- **画质平衡**：默认 VGA (640x480) 配合 `jpeg_quality = 12`，兼顾清晰度与流畅度。

### 4. 烧录与 OTA 升级步骤

#### 首次烧录 (有线)
1. 使用串口工具 (USB-TTL) 连接 ESP32-CAM。
2. 在 Arduino IDE 中打开 [esp32_firmware.ino](esp32_firmware/esp32_firmware.ino)。
3. 选择开发板 `AI Thinker ESP32-CAM` 并烧录。

#### 无线升级 (OTA) - 两种方式
一旦首次烧录完成并联网，后续升级无需 USB 线：

**方式 A：浏览器网页升级 (推荐)**
1. **导出固件**：在 Arduino IDE 中点击 `项目` -> `导出已编译的二进制文件`。
2. **访问页面**：浏览器输入 `http://esp32cam.local:8080/update`。
3. **上传更新**：点击 "选择文件"，选中导出的 `.bin` 文件，点击 "Update Firmware"。
4. **状态反馈**：观察 ESP32 背面红灯，**快闪**表示传输中，**常亮 2 秒**表示成功，之后自动重启。

**方式 B：Arduino IDE 直接无线上传**
1. **选择端口**：在 Arduino IDE 的 `工具` -> `端口` 中，选择 **网络端口 (Network Ports)** 下的 `esp32cam at 192.168.x.x`。
2. **点击上传**：像平常一样点击“上传”按钮，固件将通过 WiFi 自动推送到设备。

---

## 📱 Flutter APP 配置

### 1. 环境要求
- Flutter SDK (建议 3.0.0+)
- Android 手机 (需支持多播/mDNS)

### 2. 权限说明
APP 已配置以下关键权限：
- **Android**: `INTERNET`, `CHANGE_WIFI_MULTICAST_STATE` (用于解析 .local 域名)。
- **iOS**: `NSAllowsArbitraryLoads` (允许 HTTP 视频流)。

### 3. 使用方法
1. **配网**：若设备未联网，点击 APP 下方 "Configure Device WiFi"，连接 `ESP32-CAM-Setup` 热点进行配置。
2. **连接**：在首页输入框输入 `esp32cam.local` 或设备 IP，点击 "Start Monitoring"。
3. **切换网络**：点击首页右上角红色 WiFi 图标，确认重置后，设备将清除密码并重启，重新进入配网模式。

---

## ⚠️ 常见问题修复

- **画面不显示**：
  - 确保手机和 ESP32 在同一个 WiFi 下。
  - 若 `.local` 无法解析，请尝试直接输入 IP 地址。
- **Camera capture failed**：
  - 检查摄像头排线是否松动。
  - 确保供电电流达到 5V 2A（启动瞬间电流很大）。
- **重置 WiFi 无反应**：
  - 指令已移至 8080 端口，请确保固件已更新至最新版本。
  - 观察 ESP32 背面红灯是否快闪，若快闪说明已收到指令。

---

## 📂 项目结构
- `esp32_firmware/`: ESP32 源代码。
- `lib/`: Flutter APP 源代码。
- `pubspec.yaml`: Flutter 依赖配置。
