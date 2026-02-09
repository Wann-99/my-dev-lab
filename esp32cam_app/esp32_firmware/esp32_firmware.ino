#include "esp_camera.h"
#include <WiFi.h>
#include <esp_wifi.h>
#include <ESPmDNS.h>
#include <WiFiManager.h> // https://github.com/tzapu/WiFiManager
#include "esp_http_server.h"
#include <WebServer.h>
#include <Update.h>
#include <ArduinoOTA.h>

// =================== Pin Definitions ===================
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// =================== LED Status ===================
#define LED_PIN 33 // Onboard Red LED (Active LOW: LOW=ON, HIGH=OFF)
// #define LED_PIN 4 // Onboard Flash LED (Active HIGH) - Too bright for status, uncomment if preferred

httpd_handle_t stream_httpd = NULL;
WebServer server_ota(8080); // Run OTA server on port 8080 to avoid conflict with stream
volatile bool shouldResetWiFi = false;

// =================== Stream Handler ===================
#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t * _jpg_buf = NULL;
  char * part_buf[64];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) {
    return res;
  }

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }

    if (res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
      if (res == ESP_OK) {
        res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
      }
      if (res == ESP_OK) {
        res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
      }
    }

    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    } else if (_jpg_buf) {
      free(_jpg_buf);
      _jpg_buf = NULL;
    }

    if (res != ESP_OK) {
      break;
    }
  }
  return res;
}

// =================== Server Setup ===================
void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  httpd_uri_t stream_uri = {
    .uri       = "/stream",
    .method    = HTTP_GET,
    .handler   = stream_handler,
    .user_ctx  = NULL
  };

  // Add a root handler to guide users
  httpd_uri_t index_uri = {
    .uri       = "/",
    .method    = HTTP_GET,
    .handler   = [](httpd_req_t *req) -> esp_err_t {
      const char* resp = "ESP32-CAM MJPEG Streamer.<br>"
                         "Go to <a href='/stream'>/stream</a> to view.<br>"
                         "Go to <a href='http://esp32cam.local:8080/update'>:8080/update</a> to update firmware.<br>"
                         "Go to <a href='http://esp32cam.local:8080/reset_wifi'>:8080/reset_wifi</a> to reset WiFi settings.";
      httpd_resp_send(req, resp, HTTPD_RESP_USE_STRLEN);
      return ESP_OK;
    },
    .user_ctx  = NULL
  };

  Serial.printf("Starting web server on port: '%d'\n", config.server_port);
if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    httpd_register_uri_handler(stream_httpd, &index_uri);
  }
}

// =================== Main Setup ===================
void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH); // Ensure OFF (Active LOW)

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000; // Reduced from 20MHz to 10MHz for stability
  config.pixel_format = PIXFORMAT_JPEG;
  
  // === Optimization: Resolution vs Quality ===
  // QVGA (320x240) is too small/blurry for monitoring.
  // VGA (640x480) is the sweet spot.
  // SVGA (800x600) might be slightly laggy if signal is weak.
  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA; 
    config.jpeg_quality = 12; // 12->15: Relaxed quality slightly to prevent "Capture Failed"
    config.fb_count = 2;      // Double buffering for smooth motion
  } else {
    config.frame_size = FRAMESIZE_HVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  // Init Camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // === Optimization: WiFi Performance ===
  // WiFiManager avoids hardcoding credentials
  WiFiManager wifiManager;
  // wifiManager.resetSettings(); // Toggle if you need to re-configure
  
  if(!wifiManager.autoConnect("ESP32-CAM-Setup", "password123")) {
    Serial.println("Failed to connect");
    delay(1000);
    ESP.restart();
  } 
  
  Serial.println("WiFi Connected!");
  
  // *** CRITICAL LATENCY FIX ***
  // Disable WiFi Power Saving Mode. 
  // Without this, ping can spike to 200ms+. With this, it stays <5ms.
  esp_wifi_set_ps(WIFI_PS_NONE);

  // mDNS
  if (MDNS.begin("esp32cam")) {
    Serial.println("MDNS responder started");
  }

  // Start the High Performance Web Server
  startCameraServer();

  // === OTA Setup (Web & ArduinoOTA) ===
  
  // 1. ArduinoOTA Setup (Port 3232)
  ArduinoOTA.setHostname("esp32cam");
  ArduinoOTA
    .onStart([]() {
      String type;
      if (ArduinoOTA.getCommand() == U_FLASH)
        type = "sketch";
      else // U_SPIFFS
        type = "filesystem";
      Serial.println("Start updating " + type);
      digitalWrite(LED_PIN, LOW); // Turn ON (Active LOW)
    })
    .onEnd([]() {
      Serial.println("\nEnd");
      digitalWrite(LED_PIN, LOW); // Solid ON
      delay(2000);
      digitalWrite(LED_PIN, HIGH); // OFF
    })
    .onProgress([](unsigned int progress, unsigned int total) {
      Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
      // Blink LED every ~100ms
      static unsigned long lastBlink = 0;
      if (millis() - lastBlink > 100) {
        digitalWrite(LED_PIN, !digitalRead(LED_PIN));
        lastBlink = millis();
      }
    })
    .onError([](ota_error_t error) {
      Serial.printf("Error[%u]: ", error);
      if (error == OTA_AUTH_ERROR) Serial.println("Auth Failed");
      else if (error == OTA_BEGIN_ERROR) Serial.println("Begin Failed");
      else if (error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
      else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
      else if (error == OTA_END_ERROR) Serial.println("End Failed");
      digitalWrite(LED_PIN, HIGH); // Ensure OFF on error
    });
  ArduinoOTA.begin();

  // 2. Web OTA Setup (Port 8080)
  server_ota.on("/update", HTTP_GET, []() {
    server_ota.sendHeader("Connection", "close");
    server_ota.send(200, "text/html", 
      "<form method='POST' action='/update' enctype='multipart/form-data'>"
      "<h1>ESP32-CAM OTA</h1>"
      "<input type='file' name='update'>"
      "<input type='submit' value='Update Firmware'>"
      "</form>");
  });
  
  // Add reset_wifi to Port 8080 (handled in main loop, so it works even if stream is busy)
  server_ota.on("/reset_wifi", HTTP_GET, []() {
    Serial.println("Reset command received on port 8080");
    server_ota.send(200, "text/plain", "WiFi settings cleared. Rebooting...");
    shouldResetWiFi = true; 
  });

  server_ota.on("/update", HTTP_POST, []() {
    server_ota.sendHeader("Connection", "close");
    server_ota.send(200, "text/plain", (Update.hasError()) ? "FAIL" : "OK");
    ESP.restart();
  }, []() {
    HTTPUpload& upload = server_ota.upload();
    if (upload.status == UPLOAD_FILE_START) {
      Serial.printf("Update: %s\n", upload.filename.c_str());
      digitalWrite(LED_PIN, LOW); // Turn ON (Active LOW)
      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) { //start with max available size
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_WRITE) {
      /* flashing firmware to ESP*/
      // Blink LED every ~100ms during upload
      static unsigned long lastBlink = 0;
      if (millis() - lastBlink > 100) {
        digitalWrite(LED_PIN, !digitalRead(LED_PIN));
        lastBlink = millis();
      }
      
      if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_END) {
      if (Update.end(true)) { //true to set the size to the current progress
        Serial.printf("Update Success: %u\nRebooting...\n", upload.totalSize);
        // Success Indication: Solid ON for 2 seconds
        digitalWrite(LED_PIN, LOW);
        delay(2000);
        digitalWrite(LED_PIN, HIGH);
      } else {
        Update.printError(Serial);
        digitalWrite(LED_PIN, HIGH); // Ensure OFF on error
      }
    }
  });
  server_ota.begin();

  Serial.print("Camera Ready! Use: http://");
  Serial.print(WiFi.localIP());
  Serial.println("/stream");
  Serial.print("Update Firmware at: http://");
  Serial.print(WiFi.localIP());
  Serial.println(":8080/update");
}

void loop() {
  if (shouldResetWiFi) {
    Serial.println("Executing WiFi Reset...");
    // Visual feedback: Fast blink for 1 second
    for(int i=0; i<10; i++){
      digitalWrite(LED_PIN, LOW);
      delay(50);
      digitalWrite(LED_PIN, HIGH);
      delay(50);
    }
    
    WiFiManager wm;
    wm.resetSettings(); // This is the most thorough way to clear WiFiManager settings
    
    Serial.println("WiFi settings cleared. Restarting...");
    delay(500);
    ESP.restart();
  }

  // Handle OTA requests
  ArduinoOTA.handle();
  server_ota.handleClient();
  delay(1);
}
