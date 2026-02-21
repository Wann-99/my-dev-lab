# RoboCar-A AI Driver (Python)

This Python client enables computer vision capabilities for the RoboCar-A. It runs on your PC, receives video from the ESP32-CAM, processes it (Face Tracking), and sends control commands to the ESP32-S3 via WiFi.

## Prerequisites

1.  Python 3.8+
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```

## Usage

1.  **Power on the Car**: Ensure both ESP32-S3 (Control) and ESP32-CAM (Video) are connected to WiFi.
2.  **Get IP Addresses**: Check the Serial Monitor or Router to find the IPs.
    *   Example: Camera = `192.168.1.101`, Car = `192.168.1.102`
3.  **Run the Script**:
    ```bash
    python ai_driver.py --cam_ip <CAMERA_IP> --car_ip <CAR_IP>
    ```
    
    Example:
    ```bash
    python ai_driver.py --cam_ip 192.168.31.100 --car_ip 192.168.31.101
    ```

## Features

*   **Face Tracking**: Automatically detects faces and rotates the car to keep the face in the center.
*   **Real-time View**: Displays the video feed with detection boxes and status.
*   **Manual Override**: Press 'q' to quit.

## Customization

Edit `ai_driver.py` to change:
*   `CENTER_TOLERANCE`: How precise the centering needs to be.
*   `TURN_SPEED`: How fast the car rotates.
*   Add new OpenCV logic (e.g., Color Tracking, Line Following) in the `while` loop.
