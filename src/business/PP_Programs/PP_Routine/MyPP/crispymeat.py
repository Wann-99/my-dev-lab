from pp.core.basic import wait_ms, get_list
from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    write_flx_modbus_tcp_float,
    read_flx_modbus_tcp_float,
    modbus_tcp_open,
    modbus_tcp_close,
    modbus_tcp_write,
    socket_open,
    socket_recv,
    socket_send,
    socket_close,
    read_flx_modbus_tcp_bit
)
from pp.enums import (
    ModbusReadTypeEnum,
    BaudRateEnum,
    PartityEnum,
    DataBitsEnum,
    StopBitsEnum,
    GPIOEnum,
    ModbusTCPOutputEnum,
    SystemStateEnum
)
from pp.core.robot import (
    get_global_var,
    get_system_state,
    fault,
    set_io,
    set_global_var,
    clear_fault
)
import time

class CrispyMeat(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_crispy_meat(self):
        self.func_clear_fault()
        s = ""
        modbus_tcp_open(1, "192.168.2.100", 502)
        socket_open(1, "192.168.2.205", 20000)
        while True:
            program_running = get_system_state(SystemStateEnum.PROJECT_RUNNING)
            while program_running:
                robot_init = get_list(read_flx_modbus_tcp_bit(1, 1, 10, 1), 1)
                robot_waitting = get_list(read_flx_modbus_tcp_bit(1, 1, 11, 1), 1)
                robot_capture_successful = get_list(read_flx_modbus_tcp_bit(1, 1, 12, 1), 1)
                robot_again_waitting = get_list(read_flx_modbus_tcp_bit(1, 1, 13, 1), 1)
                robot_move_start = get_list(read_flx_modbus_tcp_bit(1, 1, 14, 1), 1)
                robot_move_to_speace = get_list(read_flx_modbus_tcp_bit(1, 1, 15, 1), 1)
                robot_finish = get_list(read_flx_modbus_tcp_bit(1, 1, 16, 1), 1)
                 
                if robot_waitting != 0:
                    socket_send(1, "1")
                    # wait_ms(500)
                    data = socket_recv(1)
                    # print(type(data))
                    if data != s:
                        print(data)
                    else:
                        print("数据为空")

    def func_clear_fault(self):
        if get_system_state(SystemStateEnum.IS_FAULT):
            clear_fault()

        # modbus_tcp_open(1, "192.168.2.100", 502)
        # test_flag = get_global_var("TestFlag")
        # set_io(GPIOEnum.MODBUSTCP_SLAVE, ModbusTCPOutputEnum.MT_FLOAT_OUT_2, 0)
        # while test_flag:
        #     print(get_list(read_flx_modbus_tcp_bit(1, 1, 10, 1), 1))
        #     if get_list(read_flx_modbus_tcp_bit(1, 1, 10, 1), 1) != "0":
        #         # print(read_flx_modbus_tcp_float(1, 1, 10, 1))
        #         set_io(GPIOEnum.MODBUSTCP_SLAVE, ModbusTCPOutputEnum.MT_FLOAT_OUT_2, -60)
        #         # write_flx_modbus_tcp_float(1, 1, 0, [-60.0])
        #     # self.func_fault()
        #
        # modbus_tcp_close(1)
    # def func_fault(self):
    #     print(fault("fault"))
