# RoboCar-A 项目架构与使用说明文档

## 1. 项目概述

RoboCar-A 是一个基于 ESP32 双 MCU 架构的智能小车项目，集成了硬件驱动、图传推流、MQTT 远程通信、AI 视觉处理（Python）以及跨平台移动端控制（Flutter App）。
该项目实现了前后端解耦与软硬件分离，支持局域网发现、内网穿透外网访问，以及基于云端元数据的 OTA 固件和 App 自动升级。

---

## 2. 全局目录结构与模块职责

```text
esp32_smart_car_app/
├── android/                  # Flutter 自动生成的 Android 原生工程配置
├── assets/                   # App 静态资源（图标、3D小车模型图片等）
├── client_python/            # 服务端 AI 视觉处理与 MQTT 脚本
│   ├── ai_driver.py          # 核心视觉脚本 (YOLO/OpenCV + paho-mqtt)
│   └── requirements.txt      # Python 依赖
├── docs/                     # 项目文档
│   ├── SERVER_SETUP.md       # 服务器搭建与内网穿透部署指南
│   ├── protocol.md           # JSON 通信协议定义
│   └── ...
├── firmware/                 # ESP32 硬件固件代码 (基于 ESP-IDF)
│   ├── esp32_camera_idf/     # ESP32-CAM 固件：负责采集图像并通过 HTTP 输出 MJPEG 视频流
│   └── esp32_smart_car_idf/  # ESP32-S3 固件：主控节点，负责电机、舵机、传感器驱动，以及 MQTT 通信
├── lib/                      # Flutter App 核心源代码
│   ├── models/
│   │   └── car_state.dart    # 核心状态管理 (Provider)，处理 MQTT 连接、设备发现、OTA 更新
│   ├── pages/                # App 界面 (首页、设备管理、控制台、设置等)
│   ├── l10n/                 # 多语言支持配置
│   └── main.dart             # App 入口文件
├── ota_updates/              # 本地/云端版本元数据存放目录
│   └── version.json          # 记录 App 和固件版本、下载地址及 SHA256 校验和
├── pubspec.yaml              # Flutter 依赖配置
└── release.ps1               # 自动化发版脚本 (编译 APK、更新版本号及生成哈希)
```

---

## 3. 核心通讯逻辑与双 MCU 架构

### 3.1 双 MCU 硬件架构
- **ESP32-S3 (主控 MCU)**: 
  - 负责底盘运动（麦克纳姆轮）、云台舵机（PCA9685）、超声波测距等。
  - 通过 WiFi 连接路由器，并作为 MQTT Client 连接到 Mosquitto 服务器。
  - **不处理图像数据**，以此保证控制的实时性和低延迟。
- **ESP32-CAM (图传 MCU)**:
  - 仅负责通过 HTTP 输出高质量的 MJPEG 视频流（默认端口 81）。
  - 不参与任何小车控制逻辑。

### 3.2 网络通讯协议
整个系统采用 **控制指令与视频流分离** 的设计：
1. **MQTT (控制流)**:
   - **代理服务器**: 部署在局域网或云端（Ubuntu）的 Mosquitto。
   - **主题 (Topics)**:
     - `robocar/control`: 接收控制指令（App 或 Python 发出）。格式为 JSON，例如 `{"cmd": "move", "vx": 0.5}`。
     - `robocar/status`: ESP32-S3 定期上报的系统状态（电量、距离、网络信号等）。
2. **HTTP (视频流 & OTA)**:
   - **视频流**: Flutter App 和 Python 视觉脚本通过访问 `http://<ESP32-CAM_IP>:81/stream` 获取实时画面。
   - **OTA 更新**: ESP32 通过 HTTP 请求下载 `.bin` 固件，App 通过 HTTP 下载 `.apk`。
3. **mDNS (局域网发现)**:
   - ESP32-S3 启动时注册 `_robocar._tcp.local` 服务。
   - App 打开时通过 mDNS 自动扫描局域网内的设备并绑定，无需手动输入 IP。

### 3.3 交互流程示例（自动跟随模式）
1. **App 触发**: 用户在 App 中点击“AI 自动”模式，App 向 MQTT `robocar/control` 发布 `{"cmd": "mode", "auto": 1}`。
2. **ESP32 接收**: S3 收到指令，进入等待状态，停止响应 App 的手动摇杆输入。
3. **Python 介入**: 运行在服务器的 `ai_driver.py` 拉取 ESP32-CAM 的视频流。
4. **视觉处理**: OpenCV 检测到人脸或目标偏离中心。
5. **AI 控制**: Python 脚本计算出转向补偿，向 MQTT 发布 `{"cmd": "move", "vw": 0.5}`。
6. **执行动作**: S3 收到 Python 发来的指令，驱动电机转向，完成视觉跟随。

---

## 4. 使用说明

### 4.1 环境搭建与部署
1. **服务器端**: 
   - 按照 `docs/SERVER_SETUP.md` 安装 Mosquitto、Python 运行环境，并配置 FRP 实现内网穿透（可选）。
2. **硬件端**:
   - 使用 ESP-IDF 编译 `firmware/esp32_smart_car_idf` 并烧录至 ESP32-S3。
   - 编译 `firmware/esp32_camera_idf` 并烧录至 ESP32-CAM。
3. **视觉脚本**:
   - 在服务器上进入 `client_python/`，执行 `pip install -r requirements.txt`。
   - 运行脚本: `python3 ai_driver.py --cam_ip <CAM_IP> --mqtt_ip <MQTT_SERVER_IP>`。
     - **`<CAM_IP>` 获取方式**：打开 App，进入“设备管理”展开对应小车卡片，在“基础信息”中查看“摄像头 IP”；或者在串口监视器中查看 ESP32-CAM 启动时的日志。
     - **`<MQTT_SERVER_IP>` 获取方式**：即您部署 Mosquitto 服务器所在主机的 IP 地址。如果在同一台服务器上运行脚本，可填 `127.0.0.1`。

### 4.2 App 端操作
1. **连接设备**: 
   - 打开 App，进入“设备管理”，点击“局域网发现”。系统会自动搜索并列出 RoboCar。
   - 点击“立即连接”，App 将通过 MQTT 与小车建立通信。
2. **操控小车**:
   - 切换到“控制台”页面，可以查看实时画面。
   - 左侧摇杆控制移动，右侧摇杆控制云台。
   - 点击顶部的“手动控制 / AI 自动”按钮，可实时切换控制权归属。
3. **系统校准与 OTA 升级**:
   - 进入“我的”页面。
   - **电压校准**: 在高级设置中输入万用表实测电压，系统将自动计算倍率。
   - **检查更新**: 点击“检查更新”，App 会请求云端的 `version.json`，若有新版本，会自动下载并校验 SHA256，安全可靠地完成 App 或固件的 OTA 升级。

### 4.3 版本发布 (开发者)
当您需要发布新版本时，在 Windows PowerShell 中运行：
```powershell
.\release.ps1 -Version "2.0.2" -Changelog "修复了已知 Bug"
```
脚本会自动修改配置、编译 Release APK、计算 SHA256，并更新 `ota_updates/version.json`。最后手动将更新后的文件推送到 GitHub 即可。