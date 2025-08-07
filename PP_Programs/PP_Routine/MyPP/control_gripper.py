from pp.core.basic import wait_ms, concat_string
from pp.settings import RobotSetting
from pp.parallel_program import ParallelProgram

from pp.core.robot import (
    clear_fault,
    get_system_state,
    get_global_var,
    set_global_var,
    set_io,
)
from pp.enums import (
    SystemStateEnum,
    ModbusWriteTypeEnum,
    GPIOEnum,
    GPIOOutPortEnum,
)
from pp.core.communication import (
    write_flx_modbus_tcp_bit,
    modbus_tcp_write,
    modbus_tcp_open,
    modbus_tcp_close,
)


class ControlGripper(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_control_gripper(self):
        """主控制循环"""
        error_code = 0
        while True:
            while get_system_state(SystemStateEnum.PROJECT_RUNNING):
                if get_global_var("ToolState") == 1:
                    self.func_open_gripper()
                    # print("open the gripper")
                    while not get_global_var("ToolState") != 1:
                        # print("Drop into loop OPenning!")
                        if not get_system_state(SystemStateEnum.PROJECT_RUNNING):
                            error_code = self.func_handle_system_status()
                            wait_ms(1)
                            break
                    # print(error_code)
                    # self.func_handle_error_code(error_code)

                elif get_global_var("ToolState") == 2:
                    self.func_close_gripper()
                    # print("close the gripper")
                    while not get_global_var("ToolState") != 2:
                        # print("Drop into loop closing!")
                        if not get_system_state(SystemStateEnum.PROJECT_RUNNING):
                            error_code = self.func_handle_system_status()
                            wait_ms(1)
                            break
                    # print(error_code)
                else:
                    error_code = 0
            # wait_ms(1)
            # print(error_code)
            # if error_code == 1:
            #     print("Pausing !")
            #     set_global_var('ToolState', 0)
            # elif error_code == 2:
            #     print("a fault!")
            # error_code = 0
            self.func_handle_error_code(error_code)
            self.func_enter_silent_mode()

    def func_handle_error_code(self, error_code):
        """
        :param error_code:
        :return:
                 1：暂停
                 2：报错
                 0：正常
        """
        if error_code == 1:
            print("Pausing !")
            set_global_var('ToolState', 0)
        elif error_code == 2:
            print("a fault!")
        error_code = 0
    def func_handle_system_status(self):
        """统一处理系统状态并返回状态码
        1：暂停
        2：报错
        0：正常
        """
        if not get_system_state(SystemStateEnum.PROJECT_RUNNING) and not get_system_state(SystemStateEnum.IS_FAULT):
            error_code = 1
            return error_code
        elif get_system_state(SystemStateEnum.IS_FAULT):
            error_code = 2
            return error_code
        else:
            return 0

    def func_enter_silent_mode(self):
        """进入静默模式"""
        print("the project is not running ")
        while not get_system_state(SystemStateEnum.PROJECT_RUNNING):
            if get_system_state(SystemStateEnum.IS_FAULT):
                clear_fault()
            wait_ms(30)

    def func_open_gripper(self):
        set_io(GPIOEnum.SYSTEM,GPIOOutPortEnum.GPIO_OUT_0, True)
        print("open_gpio_out_0")

    def func_close_gripper(self):
        set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
        print("close_gpio_out_0")
