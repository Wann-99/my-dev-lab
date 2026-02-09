#pragma once

void motor_init(void);
void motor_stop(void);
void motor_set_speed(int motor_id, int speed);
void move_car(float vx, float vy, float vw);
