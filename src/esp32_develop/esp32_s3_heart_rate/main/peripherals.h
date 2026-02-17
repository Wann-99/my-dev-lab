#ifndef PERIPHERALS_H
#define PERIPHERALS_H

#include <stdint.h>
#include <stdbool.h>

void peripherals_init(void);
void led_set(bool on);
void buzzer_set(bool on);
void buzzer_beep(int duration_ms);
bool button_is_pressed(void);
void button_register_callback(void (*callback)(void));

#endif // PERIPHERALS_H
