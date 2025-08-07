from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import (
    SystemStateEnum,
    GPIOEnum,
    ModbusTCPInputEnum
)
from pp.core.basic import (
    wait_ms
)
from pp.core.communication import (
    modbus_tcp_open,
    modbus_tcp_close,
    read_flx_modbus_tcp_float,
    write_flx_modbus_tcp_float
)
from pp.core.robot import (
    get_global_var,
    get_system_state,
    get_io
)




class ExampleModbusPP(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)


    def pp_example_modbus(self):
        if  modbus_tcp_open(1, "192.168.2.110", 20000):
            print("ModbusClient_is_connected")
            print(read_flx_modbus_tcp_float(1, 1, 0, 3))
            write_flx_modbus_tcp_float(1, 1, 0, [5, 1, -20])
            COLLECT_FLAG = get_global_var("COLLECT_FLAG")
            while COLLECT_FLAG:
                Running_state = get_system_state(SystemStateEnum.PROJECT_RUNNING)

                if Running_state:
                    print(get_io(GPIOEnum.MODBUSTCP_SLAVE, ModbusTCPInputEnum.MT_FLOAT_IN_0))
                    wait_ms(6)
                # else:print("wait_program_running")

            modbus_tcp_close(1)
        print("ModbusClient_is_disconnected")
