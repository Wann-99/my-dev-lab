idf_component_register(SRCS "main.c" "ble_hrm.c" "display_driver.c" "peripherals.c"
                    INCLUDE_DIRS "."
                    REQUIRES nvs_flash bt driver esp_lcd esp_timer freertos esp_system log esp_common)
