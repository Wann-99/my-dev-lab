from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.basic import wait_ms, get_list
from pp.core.communication import (
    modbus_tcp_open,
    # modbus_tcp_close,
    write_flx_modbus_tcp_bit,
    write_flx_modbus_tcp_int,
    # write_flx_modbus_tcp_float,
    read_flx_modbus_tcp_bit,
    read_flx_modbus_tcp_int,
)
from pp.enums import (
    GPIOEnum,
    GPIOInPortEnum,
    GPIOOutPortEnum,
    # ModbusWriteTypeEnum,
    # ModbusTCPInputEnum,
    # SystemStateEnum,
)
from pp.core.robot import (
    get_io,
    # wait_io_ms,
    # clear_fault,
    # get_system_state,
    set_io,
    set_io_pulse_ms,
)


class ControlRobot(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_control_main(self, auto_booted: bool = True, auto_looped: bool = False):
        # project_running = False
        while True:
            # print(project_running)
            self.func_rizon_light_mode()
            if get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_1) == 1:
                print("启动程序")
                if modbus_tcp_open(1, "192.168.2.100", 502):
                    # 是否有错误
                    if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 4) == "1":
                        if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 6) == "1":
                            # 清除错误
                            print("fault")
                            write_flx_modbus_tcp_bit(1, 1, 6, [False])
                            wait_ms(5)
                            write_flx_modbus_tcp_bit(1, 1, 6, [True])  # 置位线圈
                            wait_ms(100)  # 保持100ms
                        # 电机打开，没有错误 并且启动按钮按下
                        elif (
                            get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 4) == "1"
                            and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 6) == "0"
                            and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "0"
                            and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "0"
                            and get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_2) == 1
                        ):
                            print("running")
                            self.func_start_plan()
                            # project_running = True
                        # 程序运行并且启动按钮按下
                        elif (
                            get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "1"
                            or get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "1"
                        ) and get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_2) == 1:
                            print("pause")
                            self.func_pause_plan()
                            # project_running = False
                        elif (
                            get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "0"
                            and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "0"
                        ):
                            self.func_pause_plan()
                            # project_running = False
                        # 电机状态为 0 并且没有急停
                    elif (
                        get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 4) == "0"
                        and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 6) == "0"
                        and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 3) == "1"
                    ):
                        # 打开电机
                        self.func_motor_on()
                        print("motor_is_on")
                    wait_ms(500)
                else:
                    print("Modbus is not connected")
            self.func_enter_silent_mode()

    def func_motor_on(self):
        while True:
            if get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_0) == 1:
                write_flx_modbus_tcp_bit(1, 1, 4, [False])
                wait_ms(10)
                write_flx_modbus_tcp_bit(1, 1, 4, [True])  # 置位线圈
                wait_ms(100)  # 保持100ms
                write_flx_modbus_tcp_bit(1, 1, 4, [False])
                break

    def func_start_plan(self):
        project_running = False
        while not project_running:
            print(project_running)
            print("running")
            # print(program_request)
            # 准备接收方案 ID  （程序请求 为 开）
            if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 5) == "1":
                # 发送方案 至机器人  （方案ID 设定一个整型值）
                write_flx_modbus_tcp_int(1, 1, 0, [1])
                # 下发方案 （确认程序 设置上升沿）
                self.func_confirm_plan()
                # 检查方案  （方案ID状态 的值变为与输入信号 方案ID 的值相同）
                if get_list(read_flx_modbus_tcp_int(1, 1, 0, 5), 4) == 1:
                    # 允许机器人运动 （设置允许运动 为 开 ）
                    write_flx_modbus_tcp_bit(1, 1, 2, [True])
                    # 执行方案       （启动程序 设置上升沿）
                    self.func_start_program()
                    # 设置机器人运动速度  （速度倍率 设定一个整型值）
                    write_flx_modbus_tcp_int(1, 1, 1, [100])
            project_running = True

    def func_pause_plan(self):
        project_running = True
        while project_running:
            # 通知方案正在运行 （程序运行 为 开）
            # print("1111")
            if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "1":
                # 暂停方案 （暂停程序 设置上升沿）
                # print("2222")
                self.func_pause_program()
                # 通知方案已暂停（程序已暂停）
                if get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "1":
                    # 恢复方案（启动程序设置上升沿）
                    self.func_start_program()
                    # print("恢复方案")
                    # 终止方案（终止程序设置上升沿）
                    self.func_terminate_program()
                    # 通知方案已终止（程序运行为 关）
                project_running = False
            elif get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "1":
                # 恢复方案（启动程序设置上升沿）
                # print("3333")
                self.func_start_program()
                # print("恢复方案")
                # 终止方案（终止程序设置上升沿）
                self.func_terminate_program()
                # 通知方案已终止（程序运行为 关）
                project_running = False
            project_running = False

    def func_confirm_plan(self):
        print("assign")
        write_flx_modbus_tcp_bit(1, 1, 3, [False])
        wait_ms(5)
        write_flx_modbus_tcp_bit(1, 1, 3, [True])  # 置位线圈
        wait_ms(100)  # 保持100ms
        write_flx_modbus_tcp_bit(1, 1, 3, [False])

    def func_start_program(self):
        print("start")
        write_flx_modbus_tcp_bit(1, 1, 0, [False])
        wait_ms(5)
        write_flx_modbus_tcp_bit(1, 1, 0, [True])  # 置位线圈
        wait_ms(100)  # 保持100ms
        write_flx_modbus_tcp_bit(1, 1, 0, [False])

    def func_pause_program(self):
        write_flx_modbus_tcp_bit(1, 1, 1, [False])
        wait_ms(5)
        write_flx_modbus_tcp_bit(1, 1, 1, [True])  # 置位线圈
        wait_ms(100)  # 保持100ms
        write_flx_modbus_tcp_bit(1, 1, 1, [False])

    def func_terminate_program(self):
        write_flx_modbus_tcp_bit(1, 1, 5, [False])
        wait_ms(5)
        write_flx_modbus_tcp_bit(1, 1, 5, [True])  # 置位线圈
        wait_ms(100)  # 保持100ms
        write_flx_modbus_tcp_bit(1, 1, 5, [False])

    def func_enter_silent_mode(self):
        """进入静默模式"""
        # self.func_pause_program()
        while not get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_1) == 1:
            print("待机运行")
            self.func_rizon_light_mode()
            wait_ms(500)

    def func_rizon_light_mode(self):
        if modbus_tcp_open(1, "192.168.2.100", 502):
            if (
                get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "0"
                and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "1"
            ):
                print("绿灯")
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, True)
                wait_ms(5)
            elif (
                get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "0"
                and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "0"
                and get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_1) == 1
            ):
                print("黄灯闪")
                set_io_pulse_ms(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, True, 500)
                # set_io_pulse_ms(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_3, True, 500)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                wait_ms(5)
            elif (
                get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 1) == "1"
                and get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 0) == "0"
            ):
                print("黄灯常亮")
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, True)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, False)
                wait_ms(5)
            elif (
                get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 3) == "0"
                or get_list(read_flx_modbus_tcp_bit(1, 1, 0, 7), 6) == "1"
            ):
                print("红灯")
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, True)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                wait_ms(5)
            elif get_io(GPIOEnum.SYSTEM, GPIOInPortEnum.GPIO_IN_1) == 0:
                set_io_pulse_ms(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, True, 500)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, False)
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_2, False)
                wait_ms(5)
