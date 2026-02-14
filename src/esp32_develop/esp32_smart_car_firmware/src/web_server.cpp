#include "web_server.h"

void CarWebServer::begin() {
    // Setup WiFi as Access Point
    WiFi.mode(WIFI_AP);
    WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
    
    Serial.print("AP Started. IP: ");
    Serial.println(WiFi.softAPIP());

    // Start WebSocket
    webSocket.begin();
    webSocket.onEvent([this](uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
        this->onWebSocketEvent(num, type, payload, length);
    });
    
    Serial.println("WebSocket Server Started");
}

void CarWebServer::loop() {
    webSocket.loop();
}

void CarWebServer::setCommandCallback(CommandCallback callback) {
    _callback = callback;
}

void CarWebServer::sendStatus(float distance, String mode) {
    StaticJsonDocument<200> doc;
    doc["type"] = "status";
    doc["dist"] = distance;
    doc["mode"] = mode;
    
    String jsonString;
    serializeJson(doc, jsonString);
    webSocket.broadcastTXT(jsonString);
}

void CarWebServer::onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            Serial.printf("[%u] Disconnected!\n", num);
            break;
        case WStype_CONNECTED:
            Serial.printf("[%u] Connected!\n", num);
            break;
        case WStype_TEXT:
            // Parse JSON
            StaticJsonDocument<512> doc;
            DeserializationError error = deserializeJson(doc, payload);
            
            if (error) {
                Serial.print(F("deserializeJson() failed: "));
                Serial.println(error.f_str());
                return;
            }
            
            if (_callback) {
                _callback(doc);
            }
            break;
    }
}
