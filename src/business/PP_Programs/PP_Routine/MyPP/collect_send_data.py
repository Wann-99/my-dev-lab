from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import SystemStateEnum
from pp.core.basic import (
    concat_string,
    wait_ms,
    append_list, join_list
)
from pp.core.communication import (
    socket_open,
    socket_send,
    socket_close
)
from pp.core.robot import (
    get_global_var,
    get_system_state,
    get_io
)


class CollectAndSendData(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_collect_and_send_data(self, auto_booted: bool = False, auto_looped: bool = False):
        """
        采集传感器数据并通过TCP Socket发送
        """
        # 初始化空列表（假设是创建独立空列表）
        # 获取全局变量 COLLECT_FLAG
        collect_flag = get_global_var("COLLECT_FLAG")
        # 条件判断与Socket连接
        if socket_open(1, "192.168.2.201", 20000):
            # 打开TCP客户端连接
            print(socket_send(1, "Hi, Sunseed!"))  # 发送初始消息
            # print(join_string(["Hi", "Flexiv"], "_"))
            # 持续数据采集循环
            test_flag = True
            i = 0
            while test_flag:
                if collect_flag:
                    # 从系统中获取以下参数（例如：get_system_state）
                    # 追加数据到列表（假设每次采集追加新值）
                    while i < 10:
                        tcpPose = get_system_state(SystemStateEnum.TCP_POSE)  # 获取TCP位姿的函数
                        Fx = get_system_state(SystemStateEnum.CARTESIAN_FORCE_X)
                        Fy = get_system_state(SystemStateEnum.CARTESIAN_FORCE_Y)
                        Fz = get_system_state(SystemStateEnum.CARTESIAN_FORCE_Z)
                        Mx = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_X)
                        My = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_Y)
                        Mz = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_Z)
                        data_text = join_list(tcpPose, ",")  # 对应PDF的 make text from list
                        all_data = concat_string(data_text, ",", Fx, ",", Fy, ",", Fz, ",", Mx, ",", My, ",", Mz)
                        socket_send(1, all_data)  # 发送数据
                        wait_ms(6)  # 等待6毫秒（PDF的 wait 6 ms）
                        # set_global_var(COLLECT_FLAG, False)
                        i = i + 1
                    test_flag = False
                if not get_global_var("COLLECT_FLAG"):
                    break
            # 关闭Socket连接
            socket_close(1)
        print("socket connected field")