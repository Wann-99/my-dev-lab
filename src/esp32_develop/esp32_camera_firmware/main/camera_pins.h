#pragma once

#include "sdkconfig.h"

// Use Kconfig values if defined, otherwise fallback to defaults (AI-Thinker)

#if defined(CONFIG_CAMERA_MODULE_ESP32_CAM_BOARD)
    #define PWDN_GPIO_NUM     CONFIG_CAMERA_PIN_PWDN
    #define RESET_GPIO_NUM    CONFIG_CAMERA_PIN_RESET
    #define XCLK_GPIO_NUM     CONFIG_CAMERA_PIN_XCLK
    #define SIOD_GPIO_NUM     CONFIG_CAMERA_PIN_SIOD
    #define SIOC_GPIO_NUM     CONFIG_CAMERA_PIN_SIOC

    #define Y9_GPIO_NUM       CONFIG_CAMERA_PIN_Y9
    #define Y8_GPIO_NUM       CONFIG_CAMERA_PIN_Y8
    #define Y7_GPIO_NUM       CONFIG_CAMERA_PIN_Y7
    #define Y6_GPIO_NUM       CONFIG_CAMERA_PIN_Y6
    #define Y5_GPIO_NUM       CONFIG_CAMERA_PIN_Y5
    #define Y4_GPIO_NUM       CONFIG_CAMERA_PIN_Y4
    #define Y3_GPIO_NUM       CONFIG_CAMERA_PIN_Y3
    #define Y2_GPIO_NUM       CONFIG_CAMERA_PIN_Y2
    #define VSYNC_GPIO_NUM    CONFIG_CAMERA_PIN_VSYNC
    #define HREF_GPIO_NUM     CONFIG_CAMERA_PIN_HREF
    #define PCLK_GPIO_NUM     CONFIG_CAMERA_PIN_PCLK
#else
    // Fallback or explicit define for AI-Thinker
    #define PWDN_GPIO_NUM     32
    #define RESET_GPIO_NUM    -1
    #define XCLK_GPIO_NUM     0
    #define SIOD_GPIO_NUM     26
    #define SIOC_GPIO_NUM     27

    #define Y9_GPIO_NUM       35
    #define Y8_GPIO_NUM       34
    #define Y7_GPIO_NUM       39
    #define Y6_GPIO_NUM       36
    #define Y5_GPIO_NUM       21
    #define Y4_GPIO_NUM       19
    #define Y3_GPIO_NUM       18
    #define Y2_GPIO_NUM       5
    #define VSYNC_GPIO_NUM    25
    #define HREF_GPIO_NUM     23
    #define PCLK_GPIO_NUM     22
#endif

// LED Configuration
#ifdef CONFIG_LED_GPIO
    #define LED_GPIO_NUM      CONFIG_LED_GPIO
#else
    #define LED_GPIO_NUM      4  // AI-Thinker Flash LED (High Power)
#endif

#ifdef CONFIG_LED_STATUS_GPIO
    #define LED_STATUS_GPIO_NUM CONFIG_LED_STATUS_GPIO
#else
    #define LED_STATUS_GPIO_NUM 33 // AI-Thinker Red LED (Status, Active Low)
#endif

#define LED_ON_LEVEL      0  // Active Low for GPIO 33
