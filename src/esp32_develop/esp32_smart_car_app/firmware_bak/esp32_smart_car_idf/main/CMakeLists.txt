idf_component_register(SRCS "main.c" "wifi_app.c" "motor_driver.c" "pca9685.c" "websocket_server.c" "ultrasonic.c" "ota_server.c"
                    INCLUDE_DIRS "."
                    REQUIRES nvs_flash esp_wifi esp_event esp_http_server driver json esp_timer app_update esp_partition mdns esp_adc esp_http_client esp_https_ota)
