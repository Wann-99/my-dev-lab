from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    socket_open,
    socket_connected,
    socket_send,
    socket_close,
)
from pp.core.robot import (
    get_global_var,
    get_system_state,
    SystemStateEnum
)
from pp.core.basic import (
    concat_string,
    get_list,

)


class CollectForce(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_collect_force(self):

        if socket_open(1, "192.168.3.220", 20000):
            # 打开TCP客户端连接
            print(socket_send(1, "Hi, Sunseed!"))  # 发送初始消息
            # print(join_string(["Hi", "Flexiv"], "_"))
            # 持续数据采集循环
            while True:
                Force_Flag = get_global_var("starForce")
                if Force_Flag:
                    print("开始采集")
                    while Force_Flag:
                        # 从系统中获取以下参数（例如：get_system_state）
                        # 追加数据到列表（假设每次采集追加新值）
                        tcpPose = get_system_state(SystemStateEnum.TCP_POSE)  # 获取TCP位姿的函数
                        posZ = get_list(tcpPose, 2)
                        # print(posZ)
                        # Fx = get_system_state(SystemStateEnum.CARTESIAN_FORCE_X)
                        # Fy = get_system_state(SystemStateEnum.CARTESIAN_FORCE_Y)
                        Fz = get_system_state(SystemStateEnum.CARTESIAN_FORCE_Z)
                        # Mx = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_X)
                        # My = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_Y)
                        # Mz = get_system_state(SystemStateEnum.CARTESIAN_MOMENT_Z)
                        # data_text = join_list(tcpPose, ",")  # 对应PDF的 make text from list
                        # all_data = concat_string(data_text, ",", Fx, ",", Fy, ",", Fz, ",", Mx, ",", My, ",", Mz)
                        all_data = concat_string(Fz,",", posZ)
                        socket_send(1, all_data)  # 发送数据
                        if not get_global_var("starForce"):
                            print("停止采集")
                            break                       # 等待6毫秒（PDF的 wait 6 ms）
                        # set_global_var(COLLECT_FLAG, False)
                    # wait_ms(1)
                if not socket_connected(1):
                    print("socket connected field")
                    break
        # 关闭Socket连接
        socket_close(1)
    print("socket connected field")
