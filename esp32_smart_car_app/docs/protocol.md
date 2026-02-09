# 移动监控智能小车通信协议

## 1. 概述
本协议基于 WebSocket 协议进行通信，数据格式采用 JSON。
默认 WebSocket 端口：81

## 2. 指令集 (App -> ESP32)

### 2.1 移动控制
控制小车全向移动。
- `vx`: 前后速度 (-1.0 ~ 1.0)
- `vy`: 左右平移速度 (-1.0 ~ 1.0)
- `vw`: 自转速度 (-1.0 ~ 1.0)

```json
{
  "cmd": "move",
  "vx": 0.5,
  "vy": 0,
  "vw": 0
}
```

### 2.2 舵机云台控制
控制两个舵机的角度。
- `id`: 0 (水平/超声波), 1 (俯仰/摄像头)
- `angle`: 角度 (0 ~ 180)

```json
{
  "cmd": "servo",
  "id": 0,
  "angle": 90
}
```

### 2.3 工作模式切换
- `mode`: "manual" (手动), "auto" (自动避障)

```json
{
  "cmd": "mode",
  "value": "auto"
}
```

### 2.4 最大速度设置
- `value`: 0 ~ 255

```json
{
  "cmd": "speed",
  "value": 200
}
```

## 3. 状态反馈 (ESP32 -> App)

### 3.1 实时传感器数据
周期性发送或按需发送。
- `dist`: 超声波检测距离 (cm)
- `mode`: 当前模式

```json
{
  "type": "status",
  "dist": 25.4,
  "mode": "manual"
}
```

## 4. 视频流 (ESP32-CAM)
视频流独立于控制通道，通常使用 HTTP MJPEG 协议。
- 地址格式: `http://<ESP32-CAM-IP>:81/stream`
