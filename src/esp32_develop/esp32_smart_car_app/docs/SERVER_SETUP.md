# RoboCar-A 服务器搭建与内网穿透部署指南

本文档旨在指导如何在 Ubuntu Server 22.04（无桌面环境）上搭建一套可移植、免安装、支持 MQTT 通信、视觉计算、OTA 固件分发及外网访问的服务端环境。

## 一、系统与环境准备

- **操作系统**: Ubuntu Server 22.04 LTS
- **硬件配置**: i5-8250U / 8G RAM / 128G SSD 或以上
- **基础依赖**:
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y python3 python3-pip wget curl unzip systemd
  ```

## 二、部署 Mosquitto MQTT 服务器

Mosquitto 是轻量级、安全的 MQTT 代理服务器。我们将配置它支持账号密码并关闭匿名访问。

### 1. 安装 Mosquitto

```bash
sudo apt install -y mosquitto mosquitto-clients
```

### 2. 配置密码认证

创建密码文件并设置账号密码（例如：账号 `robocar`，密码 `smart2026`）：

```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd robocar
# 根据提示输入两次密码：smart2026
```

### 3. 修改 Mosquitto 配置文件

编辑配置文件：`sudo nano /etc/mosquitto/conf.d/default.conf`
输入以下内容：

```conf
listener 1883 0.0.0.0
allow_anonymous false
password_file /etc/mosquitto/passwd
```

### 4. 重启服务

```bash
sudo systemctl restart mosquitto
sudo systemctl enable mosquitto
```

## 三、部署 OTA 与 APP 更新 HTTP 服务

ESP32-S3 和 ESP32-CAM 设备的 OTA 升级以及 APP 的版本检查需要一个轻量的 HTTP 服务器。我们可以使用 Python 自带的 HTTP 服务或 Nginx。

### 1. 目录结构准备

```bash
mkdir -p /home/ubuntu/robocar_server/ota_updates
cd /home/ubuntu/robocar_server/ota_updates
# 在此目录放入 version.json, app-release.apk, main.bin, cam.bin 等文件
```

### 2. 使用 Python 启动轻量 HTTP 服务 (端口 8080)

为了保持服务的可移植性和后台运行，我们编写一个 Systemd 服务文件：

```bash
sudo nano /etc/systemd/system/robocar-ota.service
```

输入内容：

```ini
[Unit]
Description=RoboCar OTA HTTP Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/robocar_server/ota_updates
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
```

启动并设置开机自启：

```bash
sudo systemctl daemon-reload
sudo systemctl start robocar-ota
sudo systemctl enable robocar-ota
```

## 四、部署 Python 视觉识别服务

服务端将从 ESP32-CAM 获取 MJPEG 流，进行 YOLO / OpenCV 识别，并通过 MQTT 下发控制指令。

### 1. 环境安装

```bash
pip3 install paho-mqtt opencv-python-headless numpy ultralytics
```

### 2. 运行视觉脚本

将开发好的 `ai_driver.py` 放入 `/home/ubuntu/robocar_server/` 目录下。该脚本将订阅和发布 MQTT 消息。
（推荐使用 `tmux` 或 `systemd` 将其挂载到后台运行）。

### 使用 systemd（推荐最终部署使用）

systemd 是 Linux 系统的服务管理工具。它可以将您的脚本变成一个系统级服务，支持 崩溃自动重启 和 开机自动启动 。

1. 找出 Python 解释器和脚本的绝对路径 假设您的项目目录在 /home/ubuntu/esp32\_smart\_car\_app/client\_python 。
   找出 python3 的路径（通常是 /usr/bin/python3 ，如果您用了虚拟环境请使用虚拟环境里的 python 路径）。
2. 创建服务配置文件

```
sudo nano /etc/systemd/system/
robocar-ai.service
```

1. 填入以下配置内容 (注意修改 User 、 WorkingDirectory 和 ExecStart 里的路径为您服务器上的实际路径，以及脚本参数)

```
[Unit]
Description=RoboCar AI Vision Driver
After=network.target mosquitto.
service

[Service]
Type=simple
User=ubuntu
# 脚本所在的目录
WorkingDirectory=/home/ubuntu/
esp32_smart_car_app/client_python
# 启动命令 (请确保填写真实的 IP)
ExecStart=/usr/bin/python3 
ai_driver.py --cam_ip 192.168.1.101 
--mqtt_ip 127.0.0.1
# 如果脚本崩溃，5秒后自动重启
Restart=always
RestartSec=5
# 确保 Python 日志能够实时输出到 
systemd
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

保存并退出（按 Ctrl+O ，回车，再按 Ctrl+X ）。

1. 重新加载并启动服务

```
# 重新加载 systemd 使配置生效
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start robocar-ai

# 设置开机自启（可选）
sudo systemctl enable robocar-ai
```

1. 查看运行状态和日志

- 查看服务是否在运行：
  ```
  sudo systemctl status robocar-ai
  ```
- 实时查看脚本输出的日志（按 Ctrl+C 退出查看）：
  ```
  journalctl -u robocar-ai -f
  ```
- 停止服务：
  ```
  sudo systemctl stop robocar-ai
  ```

### 总结建议：

## 五、FRP 内网穿透配置

为了实现外网控制、查看图传以及远程 OTA，我们需要使用 FRP 进行内网穿透（前提是您有一台具有公网 IP 的云服务器运行 frps）。

### 1. 下载并安装 FRP 客户端 (frpc)

```bash
cd /opt
wget https://github.com/fatedier/frp/releases/download/v0.54.0/frp_0.54.0_linux_amd64.tar.gz
tar -zxvf frp_0.54.0_linux_amd64.tar.gz
mv frp_0.54.0_linux_amd64 frp
```

### 2. 配置 frpc.toml

编辑配置文件：`sudo nano /opt/frp/frpc.toml`

```toml
serverAddr = "你的公网服务器IP"
serverPort = 7000

# 1. 穿透 MQTT 控制指令
[[proxies]]
name = "robocar-mqtt"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1883
remotePort = 1883

# 2. 穿透 ESP32-CAM 视频流 (假设小车IP为192.168.1.100)
[[proxies]]
name = "robocar-cam"
type = "tcp"
localIP = "192.168.1.100"
localPort = 81
remotePort = 8081

# 3. 穿透 OTA 与更新服务
[[proxies]]
name = "robocar-ota"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 8080
```

### 3. 配置开机自启

```bash
sudo nano /etc/systemd/system/frpc.service
```

```ini
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/opt/frp/frpc -c /opt/frp/frpc.toml

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl start frpc
sudo systemctl enable frpc
```

***

**至此，服务器端的环境搭建已完成。**
小车和 APP 只需连接至服务器即可实现低延迟、安全、可远程操控的智能驾驶与视觉跟随功能。
