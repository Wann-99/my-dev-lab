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
        self.SINGLE_TURN_CMD_V1 = 0xA5
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
            cmd_list = self.func_send_angle(300.0, 0x00)
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
        angleIncrement = angle * 8 * 100.0
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

    
