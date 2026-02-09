from pp.enums import (
    SystemStateEnum,
    CoordinateSystemEnum,
    CoordinateNameEnum, MetricSystemEnum
)
from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    socket_open,
    socket_recv,
    socket_send,
    socket_connected,
)
from pp.core.robot import (
    get_global_var,
    update_object_pool,
    update_global_var_coord,
    get_system_state,
    clear_fault,
)
from pp.core.basic import (
    split_string,
    concat_string,
    get_list,
    wait_ms,
    to_number,
)


class ConvVisionTrigger(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_conv_vision_trigger(self):
        # ==================== 相机参数 ====================
        cam_intr_params = (
            '691.6986083984375, 691.6787109375, '
            '642.67529296875, 361.54461669921875, '
            '1280, 720, 0.001'
        )
        cam_extr_params = (
            '0.34559894 -0.41461863 0.83664676 '
            '-0.03670967 3.1249094 -0.00345758'
        )

        obj_name = 'Conveyor-SerialPort-1/Vision'
        recv_text = ''

        while True:
            # ==================== 建立 socket 连接 ====================
            if socket_open(1, '192.168.2.50', 30000):
                print('[Vision] is connected')

                while True:
                    # --------- 连接检测 ---------
                    if not socket_connected(1):
                        print('[Vision] Loss connection')
                        break

                    # --------- 发送 Trigger ---------
                    if not socket_send(1, 'Trigger'):
                        print('[Vision] Send fail')
                        break

                    # --------- 接收数据 ---------
                    recv_text = socket_recv(1)
                    # print(recv_text)

                    # --------- 解析并更新对象池 ---------
                    if recv_text != '':
                        obj_param = split_string(recv_text, ';')
                        obj_value = obj_param[1]
                        obj_str = split_string(obj_value, " ")
                        obj_x = to_number(get_list(obj_str, 0), 10)
                        obj_y = to_number(get_list(obj_str, 1), 10)
                        obj_z = to_number(get_list(obj_str, 2), 10)
                        obj_rx = to_number(get_list(obj_str, 3), 10)
                        obj_ry = to_number(get_list(obj_str, 4), 10)
                        obj_rz = to_number(get_list(obj_str, 5), 10)


                        obj_flag = self.func_determine_workspace(
                            obj_x, obj_y, obj_z
                        )

                        if not obj_flag:
                            update_object_pool(
                                obj_name,
                                8,
                                obj_value,
                                cam_intr_params,
                                cam_extr_params,
                                'flange',
                            )

                        else:
                            print('[Vision] Out of workspace')
                            vision_value = concat_string(
                                "[Vision] Obj value: ", obj_value
                            )
                            print(vision_value)
                            update_global_var_coord(
                                "RecvCoord",
                                [obj_x, obj_y, obj_z, obj_rx, obj_ry, obj_rz, ],
                                [CoordinateSystemEnum.WORLD, CoordinateNameEnum.WORLD_ORIGIN],
                                [0, -40, 0, 90, 0, 40, 0],
                                [1, 2, 3, 4, 5, 6],
                                MetricSystemEnum.METER,
                            )
            else:
                # socket 打不开 -> 进入静默模式
                self.func_enter_silent_mode()

    def func_enter_silent_mode(self):
        """进入静默模式"""
        print('[Vision] Enter Silent Mode')

        while not socket_open(1, '192.168.2.50', 30000):
            if get_system_state(SystemStateEnum.IS_FAULT):
                clear_fault()
            wait_ms(30)

    def func_determine_workspace(self, obj_x, obj_y, obj_z):
        """
        判断目标是否在工作空间内
        :return: True -> 超出工作空间, False -> 在工作空间内
        """
        cord1 = get_global_var("WorkSpace1")   # 左下角（单位：m）
        cord2 = get_global_var("WorkSpace2")   # 右上角

        cord1_x = get_list(cord1, 0)
        cord1_y = get_list(cord1, 1)
        cord1_z = get_list(cord1, 2)

        cord2_x = get_list(cord2, 0)
        cord2_y = get_list(cord2, 1)
        cord2_z = get_list(cord2, 2)

        if (
            cord1_x <= obj_x <= cord2_x
            and cord1_y <= obj_y <= cord2_y
            and cord1_z <= obj_z <= cord2_z
        ):
            return False
        else:
            return True
