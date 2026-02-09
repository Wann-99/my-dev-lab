# RoboCar-A Relay Server

This is a Python-based relay server for remote control of the ESP32 Smart Car.

## Features
- WebSocket relay for commands and telemetry
- MJPEG video stream proxy
- Snapshot (capture) proxy
- NAT traversal support (Relay acts as a bridge)

## How to use

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Run the server
```bash
python relay_server.py
```
The server will start on port `8081` by default.

### 3. NAT Traversal (Optional - for Public Access)
If you want to control your car from the internet, you need to make your relay server accessible.

#### Option A: Ngrok (Easiest)
1. Install [ngrok](https://ngrok.com/).
2. Run: `ngrok http 8081` (Note: ngrok works with HTTP, but for WebSockets, it works fine too).
3. Use the `Forwarding` URL provided by ngrok in your App.

#### Option B: FRP (More stable)
If you have a VPS with a public IP, use [frp](https://github.com/fatedier/frp):
1. **frps.ini (Server side - VPS)**:
   ```ini
   [common]
   bind_port = 7000
   ```
2. **frpc.ini (Client side - Your PC)**:
   ```ini
   [common]
   server_addr = YOUR_VPS_IP
   server_port = 7000

   [relay_server]
   type = tcp
   local_ip = 127.0.0.1
   local_port = 8081
   remote_port = 8081
   ```

### 4. Configure App
1. Open the App and go to **Settings** -> **Device Settings**.
2. Enable **Remote Mode**.
3. Enter your relay server address (e.g., `192.168.1.10:8081` or your ngrok/frp address).
4. Click **Save**.

## Remote Control Architecture

### 1. Local Network Mode (Default)
`App <---(WiFi)---> ESP32 Car`
- Fast, low latency.
- Both must be on the same network.

### 2. Remote Mode (Relay - Pull)
`App <---(Internet)---> Relay Server (Your PC) <---(LAN)---> ESP32 Car`
- Relay server acts as a client to the car.
- Works if your computer and car are in the same LAN.
- You can access the car from anywhere via your computer's public IP (using frp/ngrok).

### 3. Remote Mode (Relay - Push) - Recommended
`App <---(Internet)---> Relay Server (Public VPS) <---(Internet)---> ESP32 Car`
- Car acts as a client and connects to the Relay Server.
- No need for NAT traversal on the car's side.
- **Implementation Status**: 
  - ✅ Server-side logic implemented in `relay_server.py`.
  - ✅ ESP32 Client implemented in `websocket_client.c/h`.
- **How to use**:
  1. Set your `RELAY_SERVER_ADDR` in `main.c` or implement a configuration portal.
  2. The car will automatically connect to `ws://YOUR_SERVER:8081/ws?role=device&deviceId=robocar-a-v1-xxxxxx`.
  3. App connects to the same server to control the car.
