from pp.core.basic import wait_ms, get_list
from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    write_flx_modbus_tcp_float,
    read_flx_modbus_tcp_float,
    modbus_tcp_open,
    modbus_tcp_close,
    modbus_tcp_write,
    read_flx_modbus_tcp_bit,
    write_flx_modbus_tcp_int,
)
from pp.enums import (
    ModbusReadTypeEnum,
    BaudRateEnum,
    PartityEnum,
    DataBitsEnum,
    StopBitsEnum,
    GPIOEnum,
    ModbusTCPOutputEnum,
)
from pp.core.robot import get_global_var, get_system_state, fault, set_io


class SettingRobot(ParallelProgram):

    def __int__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_robotsingle(self):
        if modbus_tcp_open(1, "192.168.2.100", 502):
            write_flx_modbus_tcp_int(1, 1, 1, [100])
            wait_ms(1000)
            modbus_tcp_close(1)
