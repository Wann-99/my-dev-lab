#ifndef WEBSOCKET_CLIENT_H
#define WEBSOCKET_CLIENT_H

#include "esp_err.h"

/**
 * @brief Initialize the WebSocket client to connect to a relay server
 * 
 * @param url The WebSocket URL (e.g., ws://your-server-ip:8081/ws?role=device&deviceId=car_01)
 * @return esp_err_t 
 */
esp_err_t websocket_client_start(const char *url);

/**
 * @brief Stop the WebSocket client
 */
void websocket_client_stop(void);

/**
 * @brief Send a message through the WebSocket client
 * 
 * @param data The string message to send
 * @return esp_err_t 
 */
esp_err_t websocket_client_send(const char *data);

/**
 * @brief Check if the WebSocket client is connected
 * 
 * @return true if connected
 */
bool websocket_client_is_connected(void);

#endif // WEBSOCKET_CLIENT_H
