idf_component_register(SRCS "main.c" "wifi_app.c" "http_server.c"
                    INCLUDE_DIRS "."
                    REQUIRES esp_http_server nvs_flash esp_wifi driver esp_timer)
