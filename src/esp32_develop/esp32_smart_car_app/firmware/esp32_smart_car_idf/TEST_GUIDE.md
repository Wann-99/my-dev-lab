# ESP32 Smart Car 固件测试指南

本文档提供 ESP32 智能小车固件各核心模块的完整测试流程。测试分为**无实物模拟测试**和**实物功能测试**两个阶段。

## 1. 测试环境准备

### 1.1 硬件要求
*   **必需**：ESP32-S3 开发板
*   **必需**：USB 数据线（连接 PC）
*   **可选**：电机驱动板、电机、ESP32-CAM 模块、超声波传感器、舵机

### 1.2 软件要求
*   串口监视器工具（推荐使用 IDE 自带或 SSCOM 等）
*   手机端控制 App（需支持 WebSocket 协议）
*   波特率设置：`115200`

---

## 2. 模块测试流程

### 2.1 WiFi 连接模块 (`wifi_app.c`)

**目标**：验证 ESP32 能否成功连接到指定的 WiFi 热点并获取 IP 地址。

*   **前置条件**：在 `wifi_app.c` 中配置正确的 SSID 和密码。
*   **测试步骤**：
    1.  烧录固件并打开串口监视器。
    2.  按下复位键 (RST)。
    3.  观察串口输出。
*   **预期结果**：
    *   成功：串口打印 `got ip: 192.168.X.X`。
    *   失败：串口循环打印 `retry to connect to the AP` 或 `connect to the AP fail`。
*   **故障排查**：
    *   检查 WiFi 是否为 2.4GHz（ESP32 不支持 5GHz）。
    *   检查密码是否正确。

### 2.2 WebSocket 服务模块 (`websocket_server.c`)

**目标**：验证 WebSocket 服务器是否启动并能处理客户端连接。

*   **前置条件**：WiFi 模块测试通过。
*   **测试步骤**：
    1.  确认串口已显示 IP 地址。
    2.  打开手机 App，输入 ESP32 的 IP 地址，端口 **81**。
    3.  点击“连接”。
*   **预期结果**：
    *   串口打印：`Starting server on port: '81'`。
    *   连接成功时打印：`Handshake done, the new connection was opened`。
*   **故障排查**：
    *   确保手机和 ESP32 在同一局域网。
    *   检查 App 是否允许局域网通信权限。

### 2.3 电机驱动逻辑 (`motor_driver.c`)

**目标**：验证 App 控制指令能否正确转换为电机 PWM 信号（包含模拟测试）。

*   **模拟测试（无实物）**：
    1.  连接 App 并进入控制界面。
    2.  推动摇杆或点击方向键。
    3.  **预期结果**：串口实时打印计算日志，例如：
        ```
        Move Car: vx=0.50, vy=0.00, vw=0.00 -> M1:100, M2:100, M3:100, M4:100
        ```
        *   数值随摇杆幅度变化即为通过。

*   **实物测试（接电机）**：
    1.  接好电机驱动板电源。
    2.  发送前进指令。
    3.  **预期结果**：四个轮子均向前转动。
    4.  **故障排查**：如果轮子转动方向相反，需调整电机线序或修改代码中的引脚定义。

### 2.4 PCA9685 舵机控制 (`pca9685.c`)

**目标**：验证 I2C 通信及舵机角度控制。

*   **测试步骤**：
    1.  观察启动日志。
    2.  通过 App 发送舵机控制指令（如云台转动）。
*   **预期结果**：
    *   启动时打印：`PCA9685 Initialized`。
    *   如果未连接设备，可能打印 I2C 超时错误，但在模拟模式下不影响主程序运行。
    *   连接舵机后，舵机应随指令转动。
*   **注意**：确保 SDA/SCL 引脚连接正确（代码默认为 SDA:41, SCL:42，请根据实际板子修改 `pca9685.h`）。

### 2.5 超声波测距 (`ultrasonic.c`)

**目标**：验证距离检测功能。

*   **测试步骤**：
    1.  保持串口监视器开启。
    2.  系统主循环每秒会进行一次测距。
*   **预期结果**：
    *   串口周期性打印：`Distance: XX.XX cm`。
    *   用手遮挡传感器，数值应减小。
*   **故障排查**：
    *   如果一直显示 -1 或 0，检查 TRIG/ECHO 引脚接线。

### 2.6 ESP32-CAM 集成测试

**目标**：验证视频流与控制流的协同工作。

*   **固件准备**：
    1.  使用提供的 `esp32_camera.ino` 代码。
    2.  该代码使用了 `WiFiManager`。首次运行时，ESP32-CAM 会创建一个名为 **ESP32-CAM-Setup** 的 WiFi 热点（密码：`password123`）。
    3.  手机连接该热点，自动弹出配置页面（或访问 `192.168.4.1`），输入你的家庭 WiFi 账号密码。
    4.  配置完成后，ESP32-CAM 会重启并连接路由器。查看串口监视器获取其分配的 **IP 地址**。

*   **App 测试步骤**：
    1.  给 ESP32-CAM 独立供电。
    2.  给 ESP32-S3 小车主板供电。
    3.  打开 App，在连接页面输入：
        *   **Car Control IP**：填 ESP32-S3 的 IP（端口 81，用于控制）。
        *   **Camera Video IP**：填 ESP32-CAM 的 IP（端口 80，用于视频）。
*   **预期结果**：
    *   App 画面流畅显示摄像头内容。
    *   操作摇杆时，小车正常移动，视频无明显卡顿。

---

## 4. App UI & OTA Features

### 4.1 Interface Overview
- **HUD Style**: The App now features a modern "Heads-Up Display" interface in landscape mode.
- **Video Background**: Real-time video stream from ESP32-CAM serves as the background.
- **On-Screen Controls**:
  - **Left Joystick**: Controls car movement (Forward/Backward/Left/Right).
  - **Right Buttons**: Control Servo (Camera Pan/Tilt) and other functions.
  - **Top Bar**: Displays Connection Status, Distance (Ultrasonic), and Mode.

### 4.2 Connection & Settings
1. Launch the App.
2. Tap the **Settings (Gear Icon)** in the top-right corner.
3. Enter the IP addresses:
   - **Car IP**: Default `192.168.4.1` (or your router assigned IP).
   - **Camera IP**: Default `192.168.4.2` (or your router assigned IP).
4. Tap **Save**.
5. Tap the **Link Icon** in the top-left to connect to the Car (WebSocket). The Camera connects automatically if the IP is correct.

### 4.3 OTA Upgrade (ESP32-CAM)
1. Ensure your phone is connected to the same WiFi network as the ESP32-CAM.
2. In the App, open **Settings**.
3. Verify the **Camera IP** is correct.
4. Tap the **Open OTA Page** button.
5. This will open your phone's browser to `http://<camera_ip>:8080/update`.
6. Upload the new `.bin` firmware file for the ESP32-CAM.

---

## 5. Troubleshooting

1.  **串口无任何输出**：检查波特率是否设为 115200，检查 USB 线是否支持数据传输。
2.  **App 连不上**：检查防火墙设置，确保手机没有开启 VPN。
3.  **电机发出啸叫但不转**：PWM 频率可能过高或占空比太低（供电不足），检查电池电压。
