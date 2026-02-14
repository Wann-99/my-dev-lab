idf_component_register(SRCS "main.c" "motor_driver.c" "servo_driver.c" "sensor_driver.c" "wifi_server.c"
                       INCLUDE_DIRS "."
                       REQUIRES esp_http_server nvs_flash esp_wifi driver esp_event json esp_timer mdns)
