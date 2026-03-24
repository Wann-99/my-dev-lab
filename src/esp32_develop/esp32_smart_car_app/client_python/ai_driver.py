import cv2
import numpy as np
import paho.mqtt.client as mqtt
import json
import threading
import time
import argparse
import sys

# ================= Configuration =================
# Replace these with your actual device IPs
# ESP32-CAM (Video Source)
CAMERA_IP = "192.168.1.101" 
CAMERA_PORT = 81
CAMERA_URL = f"http://{CAMERA_IP}:{CAMERA_PORT}/stream"

# MQTT Server
MQTT_BROKER = "192.168.1.100"
MQTT_PORT = 1883
MQTT_USER = "robocar"
MQTT_PASS = "smart2026"

# Control Parameters
CENTER_TOLERANCE = 50  # Deadzone in pixels
TURN_SPEED = 0.5       # Angular velocity (rad/s approx)
# =================================================

class RoboCarAI:
    def __init__(self):
        self.mqtt_client = mqtt.Client()
        self.running = True
        self.mqtt_connected = False
        
        # Load Face Cascade
        self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print(f"Connected to MQTT Broker at {MQTT_BROKER}")
            self.mqtt_connected = True
            self.mqtt_client.subscribe("robocar/status")
        else:
            print(f"Failed to connect to MQTT, return code {rc}")

    def on_disconnect(self, client, userdata, rc):
        print("Disconnected from MQTT Broker")
        self.mqtt_connected = False

    def on_message(self, client, userdata, msg):
        # Handle status messages if needed
        pass

    def connect_mqtt(self):
        print(f"Connecting to MQTT Broker: {MQTT_BROKER} ...")
        self.mqtt_client.username_pw_set(MQTT_USER, MQTT_PASS)
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_disconnect = self.on_disconnect
        self.mqtt_client.on_message = self.on_message
        
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
        except Exception as e:
            print(f"MQTT Connection failed: {e}")
            sys.exit(1)

    def send_command(self, cmd, **kwargs):
        if self.mqtt_connected:
            payload = {"cmd": cmd}
            payload.update(kwargs)
            try:
                self.mqtt_client.publish("robocar/control", json.dumps(payload))
            except Exception as e:
                print(f"Failed to send command: {e}")

    def run(self):
        # Start MQTT Connection
        self.connect_mqtt()

        # Open Video Stream
        print(f"Opening Video Stream: {CAMERA_URL} ...")
        cap = cv2.VideoCapture(CAMERA_URL)

        if not cap.isOpened():
            print("Error: Could not open video stream. Check IP and network.")
            sys.exit(1)

        print("AI Driver Started. Press 'q' to quit.")
        
        last_cmd_time = 0
        cmd_interval = 0.1 # Limit command rate

        while self.running:
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame")
                time.sleep(1)
                continue

            # 1. Image Processing (Face Detection)
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)

            height, width, _ = frame.shape
            center_x = width // 2

            target_vx = 0.0
            target_vy = 0.0
            target_vw = 0.0
            detected = False

            # Draw center line
            cv2.line(frame, (center_x, 0), (center_x, height), (0, 255, 0), 1)

            if len(faces) > 0:
                detected = True
                # Track the largest face
                largest_face = max(faces, key=lambda r: r[2] * r[3])
                (x, y, w, h) = largest_face
                
                # Draw box
                cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 0, 0), 2)
                
                # Calculate Error
                face_center_x = x + w // 2
                error = face_center_x - center_x
                
                cv2.putText(frame, f"Error: {error}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

                # Logic: Turn to center the face
                if abs(error) > CENTER_TOLERANCE:
                    if error > 0:
                        target_vw = -TURN_SPEED # Turn Right
                        cv2.putText(frame, "Turn RIGHT", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                    else:
                        target_vw = TURN_SPEED # Turn Left
                        cv2.putText(frame, "Turn LEFT", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                else:
                    cv2.putText(frame, "CENTERED", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            
            # 2. Send Command
            current_time = time.time()
            if current_time - last_cmd_time > cmd_interval:
                if detected:
                    self.send_command("move", vx=target_vx, vy=target_vy, vw=target_vw)
                else:
                    self.send_command("move", vx=0.0, vy=0.0, vw=0.0)
                
                last_cmd_time = current_time

            # 3. Display
            cv2.imshow('RoboCar AI View', frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                self.running = False
                break

        # Cleanup
        cap.release()
        cv2.destroyAllWindows()
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='RoboCar AI Driver')
    parser.add_argument('--cam_ip', type=str, help='Camera IP Address', default=CAMERA_IP)
    parser.add_argument('--mqtt_ip', type=str, help='MQTT Broker IP Address', default=MQTT_BROKER)
    
    args = parser.parse_args()
    
    # Update Globals from Args
    CAMERA_URL = f"http://{args.cam_ip}:{CAMERA_PORT}/stream"
    MQTT_BROKER = args.mqtt_ip
    
    app = RoboCarAI()
    app.run()
