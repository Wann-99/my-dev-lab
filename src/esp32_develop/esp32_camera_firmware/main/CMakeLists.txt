idf_component_register(
    SRCS
        "app_main.c"
        "camera.c"
        "wifi.c"
    INCLUDE_DIRS "."
    REQUIRES esp32-camera
    PRIV_REQUIRES esp_http_server esp_wifi esp_netif lwip nvs_flash
)
