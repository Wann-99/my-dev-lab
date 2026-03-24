# RoboCar-A: 基于双 MCU 的智能小车控制与 AI 视觉系统

RoboCar-A 是一个集成了 Flutter 移动端应用、ESP32 双 MCU（S3 + CAM）固件以及 Python 服务端 AI 视觉的综合性智能小车方案。支持麦克纳姆轮全向移动、MJPEG 实时图传、AI 视觉跟随、内外网远程控制及基于云端的 OTA 固件更新。

## 🌟 核心特性

- **双 MCU 解耦架构**：
  - **主控 (ESP32-S3)**：负责电机、舵机、超声波及 MQTT 遥测，确保运动控制的低延迟。
  - **图传 (ESP32-CAM)**：专职提供 HTTP MJPEG 视频流，保证画面高清流畅，不阻塞主控。
- **全向移动与 AI 视觉控制**：
  - 完美支持麦克纳姆轮，实现前后、左右平移及原地自旋。
  - 服务端 Python 脚本基于 YOLO/OpenCV 自动分析图传画面，支持人脸/目标跟随。
- **双协议无缝切换**：
  - **局域网模式**：App 通过 WebSocket 直连小车，实现极致低延迟。
  - **远程模式**：基于 MQTT 协议及 FRP 内网穿透，实现外网远程操控及多端协同。
- **云端 OTA 自动升级**：
  - App 启动或点击检查更新时，基于 GitHub 上的 `version.json` 自动对比版本。
  - 支持 App 自身静默下载安装，以及对 S3/CAM 双固件的 8KB 分块流式更新（含 SHA256 校验）。
- **实时数据遥测**：
  - 超声波盲区与精确距离（2cm - 600cm，精度 ±0.1cm）。
  - 动态电池电压监测（支持 App 端万用表实测校准）。
- **赛博朋克 UI**：HUD 风格的暗色调设计，提供极佳的操控沉浸感。

## 🛠️ 硬件配置 (ESP32-S3)

### 电机驱动 (麦克纳姆轮)
| 电机 | 功能 | GPIO 引脚 |
|-------|----------|----------|
| **左前 (M1)** | PWM | 14 |
| | 方向 (IN1/IN2) | 21 / 13 |
| **右前 (M2)** | PWM | 4 |
| | 方向 (IN1/IN2) | 5 / 6 |
| **左后 (M3)** | PWM | 7 |
| | 方向 (IN1/IN2) | 15 / 16 |
| **右后 (M4)** | PWM | 17 |
| | 方向 (IN1/IN2) | 18 / 8 |

### 传感器与外设
| 组件 | 功能 | GPIO 引脚 |
|-----------|----------|----------|
| **超声波** | Trig / Echo | 9 / 10 |
| **PCA9685 (I2C)** | SDA / SCL | 11 / 12 |
| **照明灯** | 输出控制 | 2 |
| **喇叭** | 输出控制 | 3 |
| **电池电压检测** | ADC 输入 | 1 (ADC1_CH0) |

## 🚀 软件与环境部署

### 1. 详细文档导航
- [系统架构与使用说明 (PROJECT_OVERVIEW)](docs/PROJECT_OVERVIEW.md)
- [服务器搭建与内网穿透部署 (SERVER_SETUP)](docs/SERVER_SETUP.md)
- [遥测数据与通信协议说明 (TELEMETRY_DATA)](docs/TELEMETRY_DATA.md)
- [OTA 自动发版脚本使用指南](docs/OTA_GUIDE.md)

### 2. 固件编译与烧录 (ESP-IDF)
**前提条件**：安装 ESP-IDF v5.3.1 或更高版本。

1. 编译 S3 主控固件：
   ```bash
   cd firmware/esp32_smart_car_idf
   idf.py build flash monitor
   ```
2. 编译 CAM 图传固件：
   ```bash
   cd firmware/esp32_camera_idf
   idf.py build flash monitor
   ```

### 3. App 运行 (Flutter)
**前提条件**：安装 Flutter SDK (推荐 3.10.7+)。

1. 安装依赖并运行：
   ```bash
   flutter pub get
   flutter run
   ```

## 📡 通信协议摘要

- **本地直连**：基于 WebSocket (端口 80)
- **远程控制**：基于 MQTT (端口 1883)，主题 `robocar/control` 与 `robocar/status`
- **视频流**：HTTP MJPEG (端口 81)
- **指令格式示例**: `{"cmd": "move", "vx": 0.5, "vy": 0, "vw": 0.2}`

## 📝 维护与开发

- **名称统一**：项目已统一命名为 **RoboCar-A**，修改时请保持一致。
- **算法优化**：
  - 电机控制已加入软启动/平滑加减速逻辑，提升行驶稳定性。
  - 超声波检测采用多采样滤波，有效消除硬件抖动。

---
*本项目仅供学习与交流使用。*
