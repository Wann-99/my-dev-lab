#ifndef WEB_PAGE_H
#define WEB_PAGE_H

const char* index_html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <title>ESP32 Smart Car</title>
    <style>
        body { font-family: Arial; text-align: center; background-color: #f0f0f0; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .btn-group { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin: 20px 0; max-width: 300px; margin-left: auto; margin-right: auto; }
        .btn { padding: 15px; font-size: 20px; border: none; border-radius: 10px; background: #007bff; color: white; touch-action: manipulation; cursor: pointer; }
        .btn:active { background: #0056b3; }
        .btn-stop { background: #dc3545; grid-column: 2; }
        .btn-stop:active { background: #a71d2a; }
        .slider-container { margin: 20px 0; }
        input[type=range] { width: 100%; }
        .status { margin-top: 20px; padding: 10px; background: #e9ecef; border-radius: 5px; }
        .mode-switch { margin: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>ESP32 Control</h1>
        
        <div class="status">
            <div>Status: <span id="conn-status" style="color:red">Disconnected</span></div>
            <div>Distance: <span id="dist">--</span> cm</div>
            <div>Mode: <span id="mode">--</span></div>
        </div>

        <div class="mode-switch">
            <button class="btn" onclick="toggleMode()" id="mode-btn" style="background:#28a745">Switch to Auto</button>
        </div>

        <div class="slider-container">
            <label>Speed: <span id="speed-val">200</span></label>
            <input type="range" min="0" max="255" value="200" onchange="setSpeed(this.value)">
        </div>

        <div class="btn-group">
            <div></div>
            <button class="btn" ontouchstart="move(1,0,0)" ontouchend="stop()" onmousedown="move(1,0,0)" onmouseup="stop()">&#8593;</button>
            <div></div>
            
            <button class="btn" ontouchstart="move(0,1,0)" ontouchend="stop()" onmousedown="move(0,1,0)" onmouseup="stop()">&#8592;</button>
            <button class="btn btn-stop" onclick="stop()">STOP</button>
            <button class="btn" ontouchstart="move(0,-1,0)" ontouchend="stop()" onmousedown="move(0,-1,0)" onmouseup="stop()">&#8594;</button>
            
            <button class="btn" ontouchstart="move(0,0,1)" ontouchend="stop()" onmousedown="move(0,0,1)" onmouseup="stop()">&#8634;</button>
            <button class="btn" ontouchstart="move(-1,0,0)" ontouchend="stop()" onmousedown="move(-1,0,0)" onmouseup="stop()">&#8595;</button>
            <button class="btn" ontouchstart="move(0,0,-1)" ontouchend="stop()" onmousedown="move(0,0,-1)" onmouseup="stop()">&#8635;</button>
        </div>

        <div class="slider-container">
            <label>Camera Pan (H)</label>
            <input type="range" min="0" max="180" value="90" oninput="servo(0, this.value)">
        </div>
        <div class="slider-container">
            <label>Camera Tilt (V)</label>
            <input type="range" min="0" max="180" value="90" oninput="servo(1, this.value)">
        </div>
    </div>

    <script>
        var gateway = `ws://${window.location.hostname}/ws`;
        var websocket;
        
        function initWebSocket() {
            websocket = new WebSocket(gateway);
            websocket.onopen = function(event) {
                document.getElementById('conn-status').innerHTML = 'Connected';
                document.getElementById('conn-status').style.color = 'green';
            };
            websocket.onclose = function(event) {
                document.getElementById('conn-status').innerHTML = 'Disconnected';
                document.getElementById('conn-status').style.color = 'red';
                setTimeout(initWebSocket, 2000);
            };
            websocket.onmessage = function(event) {
                var data = JSON.parse(event.data);
                if (data.type == 'status') {
                    document.getElementById('dist').innerHTML = data.dist.toFixed(1);
                    document.getElementById('mode').innerHTML = data.mode;
                    var btn = document.getElementById('mode-btn');
                    if (data.mode == 'auto') {
                        btn.innerHTML = "Switch to Manual";
                        btn.style.background = "#dc3545";
                    } else {
                        btn.innerHTML = "Switch to Auto";
                        btn.style.background = "#28a745";
                    }
                }
            };
        }

        function sendCmd(data) {
            if (websocket.readyState == WebSocket.OPEN) {
                websocket.send(JSON.stringify(data));
            }
        }

        function move(vx, vy, vw) {
            sendCmd({cmd: "move", vx: vx, vy: vy, vw: vw});
        }

        function stop() {
            move(0, 0, 0);
        }

        function setSpeed(val) {
            document.getElementById('speed-val').innerHTML = val;
            sendCmd({cmd: "speed", value: parseInt(val)});
        }

        function servo(id, angle) {
            sendCmd({cmd: "servo", id: id, angle: parseInt(angle)});
        }

        function toggleMode() {
            var current = document.getElementById('mode').innerHTML;
            var next = current == 'auto' ? 'manual' : 'auto';
            sendCmd({cmd: "mode", value: next});
        }

        window.onload = initWebSocket;
    </script>
</body>
</html>
)rawliteral";

#endif
