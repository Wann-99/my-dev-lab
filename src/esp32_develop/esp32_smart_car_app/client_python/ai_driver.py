import cv2
import numpy as np
import websocket
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

# ESP32-S3 (Car Control)
CAR_IP = "192.168.1.102"
CAR_PORT = 80
CAR_WS_URL = f"ws://{CAR_IP}:{CAR_PORT}/ws"

# Control Parameters
CENTER_TOLERANCE = 50  # Deadzone in pixels
TURN_SPEED = 0.5       # Angular velocity (rad/s approx)
# =================================================

class RoboCarAI:
    def __init__(self):
        self.ws = None
        self.running = True
        self.ws_connected = False
        
        # Load Face Cascade
        self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

    def on_message(self, ws, message):
        # print(f"Car says: {message}")
        pass

    def on_error(self, ws, error):
        print(f"WebSocket Error: {error}")

    def on_close(self, ws, close_status_code, close_msg):
        print("Disconnected from Car Control")
        self.ws_connected = False

    def on_open(self, ws):
        print(f"Connected to Car Control at {CAR_WS_URL}")
        self.ws_connected = True

    def connect_car(self):
        print(f"Connecting to Car Control: {CAR_WS_URL} ...")
        self.ws = websocket.WebSocketApp(CAR_WS_URL,
                                         on_open=self.on_open,
                                         on_message=self.on_message,
                                         on_error=self.on_error,
                                         on_close=self.on_close)
        self.ws.run_forever()

    def send_command(self, cmd, **kwargs):
        if self.ws_connected and self.ws:
            payload = {"cmd": cmd}
            payload.update(kwargs)
            try:
                self.ws.send(json.dumps(payload))
            except Exception as e:
                print(f"Failed to send command: {e}")

    def run(self):
        # Start WebSocket in a separate thread
        ws_thread = threading.Thread(target=self.connect_car)
        ws_thread.daemon = True
        ws_thread.start()

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
                        target_vw = -TURN_SPEED # Turn Right (Clockwise is negative usually, check robot frame)
                        # Note: Check if Right is negative or positive for your specific robot
                        # Usually: Left is +, Right is -
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
                    # Send movement command
                    self.send_command("move", vx=target_vx, vy=target_vy, vw=target_vw)
                else:
                    # Stop if nothing detected
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
        if self.ws:
            self.ws.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='RoboCar AI Driver')
    parser.add_argument('--cam_ip', type=str, help='Camera IP Address', default=CAMERA_IP)
    parser.add_argument('--car_ip', type=str, help='Car Control IP Address', default=CAR_IP)
    
    args = parser.parse_args()
    
    # Update Globals from Args
    CAMERA_URL = f"http://{args.cam_ip}:{CAMERA_PORT}/stream"
    CAR_WS_URL = f"ws://{args.car_ip}:{CAR_PORT}/ws"
    
    app = RoboCarAI()
    app.run()
