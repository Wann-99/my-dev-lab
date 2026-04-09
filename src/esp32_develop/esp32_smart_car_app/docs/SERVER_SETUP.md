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

> **注意**：服务器无桌面，必须安装 `opencv-python-headless` 而非 `opencv-python`

```bash
pip3 install paho-mqtt opencv-python-headless numpy flask
```

### 2. 上传脚本

将开发好的 `ai_driver.py` 放入 `/home/ann/robocar_server/` 目录下。

```bash
mkdir -p /home/ubuntu/robocar_server/
# 通过 scp 或 git 将 ai_driver.py 上传到此目录
```

### 3. 手动测试运行（推荐先测试）

在正式部署为服务之前，先手动运行测试：

```bash
# --headless 参数在无桌面服务器上必须加，否则会因找不到显示器报错
python3 /home/ubuntu/robocar_server/client_python/ai_driver.py \
  --cam_ip 192.168.1.20 \
  --mqtt_ip 127.0.0.1 \
  --headless
```

### 4. 使用 systemd 部署（推荐最终部署使用）

systemd 可以将脚本变成系统级服务，支持崩溃自动重启和开机自动启动。

**创建服务配置文件：**

```bash
sudo nano /etc/systemd/system/robocar-ai.service
```

**填入以下内容**（将 `--cam_ip` 的值替换为您实际的 ESP32-CAM IP 地址）：

```ini
[Unit]
Description=RoboCar AI Vision Driver
After=network.target mosquitto.service

[Service]
Type=simple
User=ann
WorkingDirectory=/home/ann/robocar_server/
ExecStart=/usr/bin/python3 ai_driver.py --cam_ip 192.168.1.20 --mqtt_ip 127.0.0.1 --headless --stream_port 5001
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

保存并退出（按 `Ctrl+O`，回车，再按 `Ctrl+X`）。

**重新加载并启动服务：**

```bash
sudo systemctl daemon-reload
sudo systemctl start robocar-ai
sudo systemctl enable robocar-ai
```

**查看运行状态和日志：**

```bash
# 查看服务状态
sudo systemctl status robocar-ai

# 实时查看脚本日志（Ctrl+C 退出）
journalctl -u robocar-ai -f

# 停止服务
sudo systemctl stop robocar-ai
```

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

# 2. 穿透 ESP32-CAM 视频流（将 192.168.1.20 替换为实际 CAM IP）
[[proxies]]
name = "robocar-cam"
type = "tcp"
localIP = "192.168.1.20" #--cam_ip
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
