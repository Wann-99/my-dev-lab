#ifndef SENSOR_DRIVER_H
#define SENSOR_DRIVER_H

#include <stdbool.h>
#include "driver/gpio.h"

void sensor_init(void);
float sensor_get_distance(void); // Returns cm
void sensor_set_light(bool on);
void sensor_set_horn(bool on);

#endif
