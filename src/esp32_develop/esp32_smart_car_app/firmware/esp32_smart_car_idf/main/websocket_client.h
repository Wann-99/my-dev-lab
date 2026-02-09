#pragma once

#include "esp_err.h"

/**
 * @brief Initialize the WebSocket client to push data to relay server
 * 
 * @param uri The URI of the relay server (e.g. ws://1.2.3.4:8081/ws?role=device&deviceId=car01)
 * @return esp_err_t 
 */
esp_err_t websocket_client_init(const char *uri);

/**
 * @brief Stop the WebSocket client
 */
void websocket_client_stop(void);

/**
 * @brief Send a message to the relay server via WebSocket client
 * 
 * @param msg JSON string message
 */
void websocket_client_send(const char *msg);

/**
 * @brief Check if the WebSocket client is connected
 * 
 * @return true 
 * @return false 
 */
bool websocket_client_is_connected(void);
