# RoboCar-A 设备状态与遥测数据说明 (Telemetry Data)

本文档详细说明了 RoboCar-A 系统中 **主控 (ESP32-S3)** 与 **图传 (ESP32-CAM)** 上报给服务器及 App 的各项状态和数据内容。

---

## 1. 主控 (ESP32-S3) 的状态数据

主控以 **每秒 2 次 (500ms 间隔)** 的频率，将以下 JSON 格式的数据通过 MQTT 主题 `robocar/status`（本地直连模式下通过 WebSocket）主动上报给服务器和 App。

这部分数据主要反映车辆的物理运动、能源和网络状态。

### 数据字段说明：

| 字段名 | 数据类型 | 说明 | 数据示例 |
| :--- | :--- | :--- | :--- |
| `type` | String | 消息类型标识 | `"status"` |
| `dist` | Float | 超声波雷达探测到的前方障碍物距离（单位：厘米） | `25.4` |
| `v_car` | Float | 电池当前电压，由 ADC 采集并转换（单位：伏特） | `11.8` |
| `rssi` | Integer | 当前连接的 WiFi 信号强度 | `-65` |
| `mode` | String | 当前控制模式（手动控制或 AI 自动跟随） | `"MANUAL"` 或 `"AUTO"` |
| `cam_ip` | String | 自动探测或绑定的 ESP32-CAM 摄像头 IP 地址 | `"192.168.1.101"` |
| `mac` | String | 主控的物理 MAC 地址（用于 App 识别与绑定唯一设备） | `"24:D7:EB:12:34:56"` |
| `uptime` | String | 设备开机运行的持续时间（格式化后的字符串） | `"0天 2小时"` 或 `"5小时"` |
| `ssid` | String | 当前连接的 WiFi 网络名称 | `"MyHomeWiFi"` |

### JSON 示例：
```json
{
  "type": "status",
  "dist": 45.2,
  "v_car": 12.1,
  "rssi": -58,
  "mode": "MANUAL",
  "cam_ip": "192.168.1.105",
  "mac": "F4:12:FA:88:99:AA",
  "uptime": "12小时",
  "ssid": "SmartLab_5G"
}
```

---

## 2. 摄像头 (ESP32-CAM) 的状态数据

ESP32-CAM 作为一个独立的 HTTP 视频流服务器，**不主动推送 MQTT 消息**。
它提供了一个 **`http://<CAM_IP>/status`** 的 RESTful API 接口。当 App 或 Python 服务器发送 GET 请求时，它会返回当前摄像头的详尽画面配置和传感器寄存器状态。

这部分数据用于在 App 端同步和调整图像质量。

### 数据字段说明：

| 字段类别 | 包含的具体数据字段 |
| :--- | :--- |
| **基础画质** | `framesize` (分辨率), `quality` (JPEG压缩质量), `brightness` (亮度), `contrast` (对比度), `saturation` (饱和度), `sharpness` (锐度) |
| **曝光与增益 (AE/AGC)** | `aec` (自动曝光开关), `ae_level` (曝光等级), `aec_value` (曝光绝对值), `agc` (自动增益开关), `agc_gain` (增益倍数), `gainceiling` (增益上限) |
| **白平衡 (AWB)** | `awb` (自动白平衡开关), `awb_gain` (白平衡增益), `wb_mode` (白平衡模式：如晴天、阴天、办公室) |
| **画面翻转与特效** | `hmirror` (水平镜像), `vflip` (垂直翻转 - 由硬件安装方向决定), `special_effect` (特殊滤镜，如黑白、复古), `colorbar` (彩条测试模式) |
| **硬件辅助** | `led_intensity` (闪光灯/照明灯当前的 PWM 亮度值，0-255) |
| **底层 ISP** | `bpc` (坏点校正), `wpc` (白点校正), `raw_gma` (Gamma 校正), `lenc` (镜头阴影校正), `dcw` (降噪) |

### JSON 示例：
```json
{
  "framesize": 8,
  "quality": 10,
  "brightness": 1,
  "contrast": 1,
  "saturation": 0,
  "sharpness": 1,
  "special_effect": 0,
  "wb_mode": 0,
  "awb": 1,
  "awb_gain": 1,
  "aec": 1,
  "aec2": 0,
  "ae_level": 0,
  "aec_value": 300,
  "agc": 1,
  "agc_gain": 0,
  "gainceiling": 0,
  "bpc": 0,
  "wpc": 1,
  "raw_gma": 1,
  "lenc": 1,
  "hmirror": 0,
  "dcw": 1,
  "colorbar": 0,
  "led_intensity": 0
}
```

---

## 3. 架构解耦总结

- **主动推送 vs 被动拉取**：S3 是运动控制核心，对延迟极其敏感，因此通过 MQTT/WS 高频主动推送遥测数据；CAM 是视频流服务器，其配置参数修改频率低，因此采用 HTTP 接口按需拉取。
- **职责分离**：通过这种设计，在保证图传画面流畅（HTTP流）的同时，不阻塞任何底盘运动的计算与网络带宽（MQTT），从而实现双 MCU 的完美协同。
