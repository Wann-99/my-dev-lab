#ifndef SENSOR_DRIVER_H
#define SENSOR_DRIVER_H

#include <Arduino.h>
#include "config.h"

class SensorDriver {
public:
    void begin();
    float getDistance(); // Returns distance in cm
    void setLight(bool on);
    void setHorn(bool on);

private:
};

#endif
