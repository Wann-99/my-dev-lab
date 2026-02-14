#ifndef WEB_SERVER_H
#define WEB_SERVER_H

#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>
#include "config.h"

// Callback for received JSON commands
typedef std::function<void(JsonDocument&)> CommandCallback;

class CarWebServer {
public:
    void begin();
    void loop();
    void setCommandCallback(CommandCallback callback);
    void sendStatus(float distance, String mode);

private:
    WebSocketsServer webSocket = WebSocketsServer(WS_PORT);
    CommandCallback _callback;

    void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length);
};

#endif
