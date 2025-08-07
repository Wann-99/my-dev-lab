from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.basic import wait_ms, get_list
from pp.core.communication import (
    modbus_tcp_open,
    modbus_tcp_close,
    write_flx_modbus_tcp_bit,
    write_flx_modbus_tcp_int,
    write_flx_modbus_tcp_float,
    read_flx_modbus_tcp_bit, read_flx_modbus_tcp_int
)
from pp.enums import (
    GPIOEnum,
    GPIOInPortEnum,
    GPIOOutPortEnum,
    ModbusWriteTypeEnum,
    ModbusTCPInputEnum,
    SystemStateEnum)
from pp.core.robot import (
    get_io,
    wait_io_ms,
    clear_fault,
    get_system_state,
    set_io,
    set_io_pulse_ms
    )



class ControlRobot_1(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_control_sub(self):
        while True:
            if modbus_tcp_open(1, "192.168.2.100", 502):
                if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "1":
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, False)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, True)
                    wait_ms(5)
                elif get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "1":
                    set_io_pulse_ms(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, True, 1000)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                    wait_ms(1000)
                elif get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 3) == "0":
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, True)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, False)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                    wait_ms(5)
                else:
                    set_io_pulse_ms(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, True, 1000)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                    set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                    wait_ms(1000)
