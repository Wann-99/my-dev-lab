import time
import math

from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import (
    BaudRateEnum,
    PartityEnum,
    DataBitsEnum,
    StopBitsEnum,
    NumberFormatEnum,
)
from pp.core.basic import (
    concat_string,
    to_string,
    to_number,
    append_list,
)
from pp.core.communication import(
    serial_port_close,
    serial_port_open,
    serial_port_recv,       
    serial_port_send,
)



class USBMotorTxClient(ParallelProgram):
    
    

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

        self.FRAME_HEADER = 0x3E
        self.SINGLE_TURN_CMD_V2 = 0xA6
        self.READ_SINGLE_ANGLE_CMD = 0x94
        self.SET_ZERO_POINT_CMD = 0x19
        self.INCREMENTAL_POS_CMD_V2 = 0xA8
        self.DEFAULT_MOTOR_ID = 0x01
        self.MAX_SPEED = 600000
        self.SPEED = 50
        self.RUNNING = 0x88

    def pp_motor(self):
        connected = self.func_connect()
        if connected:
            #设置零点
            # serial_port_send(1, [0x3E, 0x19, 0x01, 0x00, 0x58])
            # 运行
            # serial_port_send(1,  [0x3E, 0x88, 0x01, 0x00, 0xC7])
            # 发送角度指令
            # serial_port_send(1, [0x3E, 0xA5, 0x01, 0x04, 0xE8, 0x01, 0x1E, 0x46, 0x00, 0x65])
            # print([0x3E, 0xA5, 0x01, 0x04, 0xE8, 0x00, 0x1E, 0x46, 0x00, 0x64])
            # resp = serial_port_recv(1, 16)
            # print(resp)
            # cmd_list = self.func_send_angle_v2(30.0, 0x00, 50)
            cmd_list = self.func_move_to_angle_v2(20.0, 75, motor_id=1)
            print(cmd_list)
            serial_port_send(1, cmd_list)
            resp = serial_port_recv(1, 16)
            print(resp)

            # self.func_DEC_to_HEX(180)
            serial_port_close(1)



    def func_connect(self):
        if serial_port_open(
            1,
            "/dev/serusb2",
            BaudRateEnum.BAUD_115200,
            PartityEnum.NONE,
            DataBitsEnum.BIT_8,
            StopBitsEnum.BIT_1,
        ):
            print("Motor connection successful")
            return True
        print("Motor connection failed")
        serial_port_close(1)
        return False



    def func_send_angle(self, angle: float, direction: int):
        """ send angle to motor
        :param angle:
        """

        if not (0.0 <= angle <= 359.99):
            print("角度需在0~359.99范围内")

        # 1. 构造帧[0]~[4]
        frame_list = []
        angleIncrement = math.floor(angle * 8 * 100.0)
        frame_header_num = to_number("0x3E", NumberFormatEnum.DEC)
        single_turn_cmd_v1_num = to_number("0xA5", NumberFormatEnum.DEC)
        default_motor_id_num = to_number("0x01", NumberFormatEnum.DEC)
        data_len_num = to_number("0x04", NumberFormatEnum.DEC)
        append_list(frame_list, frame_header_num)
        append_list(frame_list, single_turn_cmd_v1_num)
        append_list(frame_list, default_motor_id_num)
        append_list(frame_list, data_len_num)
        header_sum_low = (frame_header_num + single_turn_cmd_v1_num + default_motor_id_num + data_len_num) % 256
        append_list(frame_list, header_sum_low)
       
        

        # 2. 构造DATA[0]~DATA[3]
        direction_str = concat_string("0x", to_string(direction, NumberFormatEnum.HEX))
        angle_str = concat_string("0x", to_string(angleIncrement, NumberFormatEnum.HEX))
        print(angle_str)
        low_angle_str = concat_string("0x", to_string(to_number(angle_str, NumberFormatEnum.HEX) % 256, NumberFormatEnum.HEX))
        high_angle_str = concat_string("0x", to_string(math.floor(to_number(angle_str, NumberFormatEnum.HEX) / 256), NumberFormatEnum.HEX))
        angleControl_str = to_string(to_number(angle_str, NumberFormatEnum.HEX) / 65532, NumberFormatEnum.HEX)
        direction_num = to_number(direction_str, NumberFormatEnum.DEC)
        low_angle_num = to_number(low_angle_str, NumberFormatEnum.DEC)
        high_angle_num = to_number(high_angle_str, NumberFormatEnum.DEC)

        append_list(frame_list, direction_num)
        append_list(frame_list, low_angle_num)
        append_list(frame_list, high_angle_num)
        append_list(frame_list, angleControl_str)
        data_sum_low = (direction_num + low_angle_num + high_angle_num + to_number(angleControl_str, NumberFormatEnum.DEC)) % 256
        append_list(frame_list, data_sum_low)
        return frame_list

    def func_send_angle_v2(self, angle: float, direction: int, speed_percentage: int, motor_id: int = None):
        if not (0.0 <= angle <= 359.99):
            print("角度需在0~359.99范围内")

        frame_list = []
        frame_header_num = to_number("0x3E", NumberFormatEnum.DEC)
        single_turn_cmd_v2_num = to_number("0xA6", NumberFormatEnum.DEC)
        mid = motor_id
        if mid == None:
            mid = 1
        if mid < 1 or mid > 32:
            print("电机ID需在1~32范围内")
            mid = 1
        mid_mod = mid % 256
        motor_id_str = concat_string("0x", to_string(mid_mod, NumberFormatEnum.HEX))
        motor_id_num = to_number(motor_id_str, NumberFormatEnum.DEC)
        data_len_num = to_number("0x08", NumberFormatEnum.DEC)
        append_list(frame_list, frame_header_num)
        append_list(frame_list, single_turn_cmd_v2_num)
        append_list(frame_list, motor_id_num)
        append_list(frame_list, data_len_num)
        header_sum_low = (frame_header_num + single_turn_cmd_v2_num + motor_id_num + data_len_num) % 256
        append_list(frame_list, header_sum_low)

        direction_str = concat_string("0x", to_string(direction, NumberFormatEnum.HEX))
        direction_num = to_number(direction_str, NumberFormatEnum.DEC)

        angle_increment = math.floor(angle * 8 * 100.0)
        angle_str = concat_string("0x", to_string(angle_increment, NumberFormatEnum.HEX))
        angle_low_str = concat_string("0x", to_string(to_number(angle_str, NumberFormatEnum.HEX) % 256, NumberFormatEnum.HEX))
        angle_mid_str = concat_string("0x", to_string(math.floor(to_number(angle_str, NumberFormatEnum.HEX) / 256) % 256, NumberFormatEnum.HEX))
        angle_high_str = concat_string("0x", to_string(math.floor(to_number(angle_str, NumberFormatEnum.HEX) / 65536) % 256, NumberFormatEnum.HEX))
        angle_low_num = to_number(angle_low_str, NumberFormatEnum.DEC)
        angle_mid_num = to_number(angle_mid_str, NumberFormatEnum.DEC)
        angle_high_num = to_number(angle_high_str, NumberFormatEnum.DEC)

        max_speed_val = math.floor(600000 * (speed_percentage / 100.0))
        speed_str = concat_string("0x", to_string(max_speed_val, NumberFormatEnum.HEX))
        speed_b0_str = concat_string("0x", to_string(to_number(speed_str, NumberFormatEnum.HEX) % 256, NumberFormatEnum.HEX))
        speed_b1_str = concat_string("0x", to_string(math.floor(to_number(speed_str, NumberFormatEnum.HEX) / 256) % 256, NumberFormatEnum.HEX))
        speed_b2_str = concat_string("0x", to_string(math.floor(to_number(speed_str, NumberFormatEnum.HEX) / 65536) % 256, NumberFormatEnum.HEX))
        speed_b3_str = concat_string("0x", to_string(math.floor(to_number(speed_str, NumberFormatEnum.HEX) / 16777216) % 256, NumberFormatEnum.HEX))
        speed_b0_num = to_number(speed_b0_str, NumberFormatEnum.DEC)
        speed_b1_num = to_number(speed_b1_str, NumberFormatEnum.DEC)
        speed_b2_num = to_number(speed_b2_str, NumberFormatEnum.DEC)
        speed_b3_num = to_number(speed_b3_str, NumberFormatEnum.DEC)

        append_list(frame_list, direction_num)
        append_list(frame_list, angle_low_num)
        append_list(frame_list, angle_mid_num)
        append_list(frame_list, angle_high_num)
        append_list(frame_list, speed_b0_num)
        append_list(frame_list, speed_b1_num)
        append_list(frame_list, speed_b2_num)
        append_list(frame_list, speed_b3_num)
        data_sum_low = (direction_num + angle_low_num + angle_mid_num + angle_high_num + speed_b0_num + speed_b1_num + speed_b2_num + speed_b3_num) % 256
        append_list(frame_list, data_sum_low)
        return frame_list

    def func_read_single_angle(self, motor_id: int = None):
        frame_list = []
        frame_header_num = to_number("0x3E", NumberFormatEnum.DEC)
        read_single_angle_cmd_num = to_number("0x94", NumberFormatEnum.DEC)
        mid = motor_id
        if mid == None:
            mid = 1
        if mid < 1 or mid > 32:
            print("电机ID需在1~32范围内")
            mid = 1
        mid_mod = mid % 256
        motor_id_str = concat_string("0x", to_string(mid_mod, NumberFormatEnum.HEX))
        motor_id_num = to_number(motor_id_str, NumberFormatEnum.DEC)
        data_len_num = to_number("0x00", NumberFormatEnum.DEC)
        append_list(frame_list, frame_header_num)
        append_list(frame_list, read_single_angle_cmd_num)
        append_list(frame_list, motor_id_num)
        append_list(frame_list, data_len_num)
        header_sum_low = (frame_header_num + read_single_angle_cmd_num + motor_id_num + data_len_num) % 256
        append_list(frame_list, header_sum_low)
        serial_port_send(1, frame_list)
        resp = serial_port_recv(1, 10)
        if resp:
            cmd_sum_low = (resp[0] + resp[1] + resp[2] + resp[3]) % 256
            data_sum_low = (resp[5] + resp[6] + resp[7] + resp[8]) % 256
            raw_value = resp[5] + resp[6] * 256 + resp[7] * 65536 + resp[8] * 16777216
            angle_deg = (raw_value * 0.01) / 8
            return angle_deg
        return 0.0

    def func_move_to_angle_v2(self, target_angle: float, speed_percentage: int, motor_id: int = None):
        current_angle = self.func_read_single_angle(motor_id)
        cw = (target_angle - current_angle + 360.0) % 360.0
        ccw = (current_angle - target_angle + 360.0) % 360.0
        direction = 0
        delta = cw
        if cw <= ccw:
            direction = 0x00
            delta = cw
        else:
            direction = 0x01
            delta = ccw
        return self.func_send_angle_v2(delta, direction, speed_percentage, motor_id)

    
