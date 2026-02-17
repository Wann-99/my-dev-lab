#ifndef BLE_SERVER_H
#define BLE_SERVER_H

#include <stdint.h>

void ble_server_init(void);
void ble_server_update_hr(uint16_t hr_val);

#endif // BLE_SERVER_H
