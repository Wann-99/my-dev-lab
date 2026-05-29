# ESP32 Smart Car 固件 (RoboCar-A)

RoboCar-A 的 ESP32-S3 固件，基于 ESP-IDF 框架开发。负责底层硬件控制、传感器数据采集及与移动端 App 的 WebSocket 通信。

## 1. 快速开始 (Quick Start)

### 1.1 开发环境
*   **框架**: ESP-IDF v5.0 或更高版本 (推荐 v5.3)
*   **硬件**: ESP32-S3 开发板 (N16R8 推荐)
*   **电机**: N20 直流减速电机 (7PPR, 30:1 减速比, 100kHz 霍尔响应)
*   **工具**: VS Code (ESP-IDF 插件) 或命令行

### 1.2 编译与烧录
在当前目录 (`firmware/esp32_smart_car_idf`) 下执行：

```bash
# 1. 设置目标芯片
idf.py set-target esp32s3

# 2. 配置 (可选，修改 WiFi SSID/密码等)
idf.py menuconfig

# 3. 编译
idf.py build

# 4. 烧录 (PORT 替换为实际串口号，如 COM3 或 /dev/ttyUSB0)
idf.py -p PORT flash

# 5. 监控日志
idf.py -p PORT monitor
```

---

## 2. 硬件配置 (Pinout Configuration)

固件基于 ESP32-S3 开发，以下引脚定义均提取自源代码 (`main.c`, `motor_driver.c`, `ultrasonic.c`, `pca9685.h`)。

### 2.1 电机驱动 (Motor Driver)
支持 PID 和 滑模控制 (SMC) 两种闭环策略。

**电机规格 (N20)**：
*   **类型**: N20 DC Gear Motor
*   **编码器**: AB相霍尔编码器
*   **PPR (基础脉冲)**: 7
*   **减速比**: 30:1
*   **总分辨率**: 7 * 30 * 4 (倍频) = 840 counts/rev

**电机线序**：
*   **M+ / M-**: 电机电源线
*   **GND / VCC**: 编码器电源 (3.3V)
*   **A / B**: 编码器信号线

| 电机通道 | PWM 引脚 | IN1 引脚 | IN2 引脚 | 编码器 A相 | 编码器 B相 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Motor 1** | GPIO 14 | GPIO 21 | GPIO 13 | GPIO 39 | GPIO 40 | 左前轮 |
| **Motor 2** | GPIO 4 | GPIO 5 | GPIO 6 | GPIO 41 | GPIO 42 | 右前轮 |
| **Motor 3** | GPIO 7 | GPIO 15 | GPIO 16 | GPIO 43 | GPIO 44 | 左后轮 |
| **Motor 4** | GPIO 17 | GPIO 18 | GPIO 8 | GPIO 45 | GPIO 46 | 右后轮 |

### 2.2 传感器与外设 (Sensors & Peripherals)

| 模块 | 引脚/参数 | 详细说明 |
| :--- | :--- | :--- |
| **超声波 (Ultrasonic)** | TRIG: GPIO 9<br>ECHO: GPIO 10 | 测距范围 2cm - 400cm |
| **舵机驱动 (PCA9685)** | SDA: GPIO 11<br>SCL: GPIO 12 | I2C 地址: `0x40`<br>频率: 50Hz (默认) |
| **车灯 (Light)** | GPIO 2 | 高电平点亮 |
| **喇叭 (Horn)** | GPIO 3 | 高电平触发 |
| **电池电压检测** | GPIO 1 (ADC1_CH0) | 12V 分压检测 (约 1:4 分压比) |

---

## 3. 核心功能描述

### 3.1 WiFi 连接与 WebSocket
*   **模式**: Station (连接路由器) / SoftAP (热点模式)。
*   **WebSocket 端口**: `80` (路径 `/` 或 `/ws`)。
*   **功能**: 接收 JSON 指令，实时推送状态。

### 3.2 自适应控制策略 (Adaptive Control)
本固件实现了两种高级控制策略，可根据需求实时切换：

#### A. PID 控制 (Adaptive PID)
*   **特点**: 经典控制算法，适合稳态调速。
*   **自适应**:
    *   **低速增强**: 在低速区间自动增加 Kp/Ki，克服静摩擦力 (Stiction)。
    *   **抗堵转**: 检测到大误差时自动增加 Kp。

#### B. 滑模控制 (Sliding Mode Control - SMC)
*   **特点**: 鲁棒性强，对负载变化和扰动不敏感。
*   **原理**: 基于指数趋近律，通过切换函数强迫系统状态保持在滑模面上。
*   **自适应**:
    *   **边界层自适应**: 稳态时放宽边界层 (减少抖动)，瞬态时收紧边界层 (提高响应)。
    *   **增益调度**: 根据速度分段调整切换增益 $k_{sw}$。

---

## 4. 通信协议 (Protocol)

### 4.1 基础控制
**移动**:
```json
{ "cmd": "move", "vx": 0.5, "vy": 0.0, "vw": 0.0 }
```

**舵机**:
```json
{ "cmd": "servo", "channel": 0, "angle": 90 }
```

### 4.2 高级控制与调试 (New!)

**切换控制策略**:
```json
{ "cmd": "strategy", "value": 0 } // 0: PID, 1: SMC
```

**在线调整 PID 参数**:
```json
{
  "cmd": "pid_set",
  "kp": 1.5,
  "ki": 0.5,
  "kd": 0.1
}
```

**在线调整 SMC 参数**:
```json
{
  "cmd": "smc_set",
  "k_sw": 200.0,    // 切换增益
  "k_p": 1.0,       // 比例增益
  "boundary": 50.0  // 边界层厚度
}
```

### 4.3 状态反馈
```json
{
  "type": "status",
  "dist": 120.5,
  "batt": 11.2,
  "rssi": -55
}
```

---

## 5. 调试指南 (Tuning Guide)

### 5.1 PID 调试
1.  **现象**: 低速不转。 -> **对策**: 增加 `PID_LOW_SPEED_THRESHOLD` 范围内的 `BOOST_KP`。
2.  **现象**: 停车时来回摆动。 -> **对策**: 减小 `PID_KP` 或增加死区。

### 5.2 SMC 调试
1.  **现象**: 电机高频啸叫 (Chattering)。 -> **对策**: 增加 `boundary` (边界层厚度) 或减小 `k_sw`。
2.  **现象**: 响应迟钝。 -> **对策**: 增加 `k_sw` 或 `k_p`。
3.  **优势**: 在电池电压下降或负载增加（爬坡）时，SMC 通常比 PID 表现更稳定。
