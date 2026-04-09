import cv2
import numpy as np
import paho.mqtt.client as mqtt
import json
import threading
import time
import argparse
import sys
import os
from flask import Flask, Response

# ================= Configuration =================
CAMERA_IP = "192.168.1.101"
CAMERA_PORT = 81
CAMERA_URL = f"http://{CAMERA_IP}:{CAMERA_PORT}/stream"

MQTT_BROKER = "192.168.1.100"
MQTT_PORT = 1883
MQTT_USER = "robocar"
MQTT_PASS = "smart2026"

AI_STREAM_PORT = 5001      # Port for the AI-processed MJPEG stream
CENTER_TOLERANCE = 50      # Deadzone in pixels
TURN_SPEED = 0.5
# =================================================

HEADLESS = False


class RoboCarAI:
    def __init__(self):
        try:
            self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        except AttributeError:
            self.mqtt_client = mqtt.Client()

        self.running = True
        self.mqtt_connected = False
        self.tracking_active = False   # Controlled via robocar/ai_control MQTT topic

        # Thread-safe latest processed frame for Flask to serve
        self.latest_frame = None
        self.frame_lock = threading.Lock()

        self.face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        )

    # ---- MQTT callbacks ----

    def on_connect(self, client, userdata, flags, reason_code, properties=None):
        if reason_code == 0:
            print(f"[MQTT] Connected to broker at {MQTT_BROKER}")
            self.mqtt_connected = True
            self.mqtt_client.subscribe("robocar/status")
            self.mqtt_client.subscribe("robocar/ai_control")
        else:
            print(f"[MQTT] Connection failed, reason code {reason_code}")

    def on_disconnect(self, client, userdata, flags, reason_code=None, properties=None):
        print("[MQTT] Disconnected from broker")
        self.mqtt_connected = False

    def on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode())

            if msg.topic == "robocar/ai_control":
                active = data.get("active", False)
                self.tracking_active = bool(active)
                print(f"[AI] Tracking {'STARTED' if self.tracking_active else 'STOPPED'} via MQTT")
                return

            if msg.topic == "robocar/status":
                # Could monitor car state here if needed
                pass
        except Exception:
            pass

    def connect_mqtt(self):
        print(f"[MQTT] Connecting to {MQTT_BROKER}:{MQTT_PORT} ...")
        self.mqtt_client.username_pw_set(MQTT_USER, MQTT_PASS)
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_disconnect = self.on_disconnect
        self.mqtt_client.on_message = self.on_message
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
        except Exception as e:
            print(f"[MQTT] Connection failed: {e}")
            sys.exit(1)

    def send_command(self, cmd, **kwargs):
        if self.mqtt_connected:
            payload = {"cmd": cmd}
            payload.update(kwargs)
            try:
                self.mqtt_client.publish("robocar/control", json.dumps(payload))
            except Exception as e:
                print(f"[MQTT] Failed to send command: {e}")

    # ---- Flask MJPEG stream server ----

    def _generate_mjpeg(self):
        """Generator that yields the latest processed frame as MJPEG."""
        while True:
            with self.frame_lock:
                frame = self.latest_frame.copy() if self.latest_frame is not None else None
            if frame is not None:
                ret, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
                if ret:
                    yield (
                        b'--frame\r\n'
                        b'Content-Type: image/jpeg\r\n\r\n' +
                        jpeg.tobytes() +
                        b'\r\n'
                    )
            time.sleep(0.033)  # ~30 fps

    def start_stream_server(self):
        """Run a Flask MJPEG server in a background thread."""
        flask_app = Flask(__name__)
        ai = self

        @flask_app.route('/ai_stream')
        def ai_stream():
            return Response(
                ai._generate_mjpeg(),
                mimetype='multipart/x-mixed-replace; boundary=frame'
            )

        @flask_app.route('/health')
        def health():
            return {"status": "ok", "tracking": ai.tracking_active}

        # Silence Flask startup logs
        import logging
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)

        print(f"[Stream] AI MJPEG stream server started → http://0.0.0.0:{AI_STREAM_PORT}/ai_stream")
        flask_app.run(host='0.0.0.0', port=AI_STREAM_PORT, threaded=True)

    # ---- Main loop ----

    def run(self):
        self.connect_mqtt()

        # Start the MJPEG stream server in a daemon thread
        stream_thread = threading.Thread(target=self.start_stream_server, daemon=True)
        stream_thread.start()

        print(f"[Video] Opening camera stream: {CAMERA_URL} ...")
        cap = cv2.VideoCapture(CAMERA_URL)
        if not cap.isOpened():
            print("[Video] ERROR: Could not open camera stream. Check IP and network.")
            sys.exit(1)

        print("[AI] Ready. Waiting for robocar/ai_control MQTT message to start tracking.")
        if not HEADLESS:
            print("[AI] Press 'q' in the video window to quit.")

        last_cmd_time = 0
        cmd_interval = 0.1  # Send at most 10 commands per second

        while self.running:
            ret, frame = cap.read()
            if not ret:
                print("[Video] Failed to read frame, retrying...")
                time.sleep(1)
                continue

            height, width, _ = frame.shape
            center_x = width // 2

            target_vx = 0.0
            target_vy = 0.0
            target_vw = 0.0
            detected = False

            # ---- Face detection ----
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)

            # Always draw center line for reference
            cv2.line(frame, (center_x, 0), (center_x, height), (0, 255, 0), 1)

            # Draw tracking status overlay
            status_text = "TRACKING: ON" if self.tracking_active else "TRACKING: OFF"
            status_color = (0, 255, 100) if self.tracking_active else (0, 100, 255)
            cv2.putText(frame, status_text, (10, height - 15),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 2)

            if len(faces) > 0:
                detected = True
                largest_face = max(faces, key=lambda r: r[2] * r[3])
                (x, y, w, h) = largest_face

                # Draw detection box
                box_color = (0, 255, 0) if self.tracking_active else (100, 100, 255)
                cv2.rectangle(frame, (x, y), (x + w, y + h), box_color, 2)

                # Draw face center dot
                face_cx = x + w // 2
                face_cy = y + h // 2
                cv2.circle(frame, (face_cx, face_cy), 5, box_color, -1)

                error = face_cx - center_x
                cv2.putText(frame, f"Error: {error:+d}px", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

                if abs(error) > CENTER_TOLERANCE:
                    target_vw = -TURN_SPEED if error > 0 else TURN_SPEED
                    direction = "Turn RIGHT" if error > 0 else "Turn LEFT"
                    cv2.putText(frame, direction, (10, 60),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                else:
                    cv2.putText(frame, "CENTERED", (10, 60),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            else:
                cv2.putText(frame, "No face", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (150, 150, 150), 1)

            # ---- Update shared frame for Flask stream ----
            with self.frame_lock:
                self.latest_frame = frame

            # ---- Send MQTT commands (only when tracking is active) ----
            current_time = time.time()
            if self.tracking_active and (current_time - last_cmd_time > cmd_interval):
                if detected:
                    self.send_command("move", vx=target_vx, vy=target_vy, vw=target_vw)
                else:
                    self.send_command("move", vx=0.0, vy=0.0, vw=0.0)
                last_cmd_time = current_time

            # ---- Display (only in non-headless mode) ----
            if not HEADLESS:
                cv2.imshow('RoboCar AI View', frame)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    self.running = False
                    break
            else:
                time.sleep(0.01)

        # Cleanup
        cap.release()
        if not HEADLESS:
            cv2.destroyAllWindows()
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='RoboCar AI Driver')
    parser.add_argument('--cam_ip', type=str, default=CAMERA_IP,
                        help='Camera IP address (default: %(default)s)')
    parser.add_argument('--mqtt_ip', type=str, default=MQTT_BROKER,
                        help='MQTT broker IP address (default: %(default)s)')
    parser.add_argument('--headless', action='store_true',
                        help='Run without display window (required on headless servers)')
    parser.add_argument('--stream_port', type=int, default=AI_STREAM_PORT,
                        help=f'AI MJPEG stream port (default: {AI_STREAM_PORT})')

    args = parser.parse_args()

    CAMERA_URL = f"http://{args.cam_ip}:{CAMERA_PORT}/stream"
    MQTT_BROKER = args.mqtt_ip
    HEADLESS = args.headless
    AI_STREAM_PORT = args.stream_port

    if HEADLESS:
        print("[INFO] Running in headless mode (no display window).")
    print(f"[INFO] AI stream will be available at http://0.0.0.0:{AI_STREAM_PORT}/ai_stream")

    app = RoboCarAI()
    app.run()
