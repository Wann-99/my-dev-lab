from pp.settings import RobotSetting
from pp.enums import GPIOEnum, GPIOOutPortEnum, SystemStateEnum

from pp.parallel_program import ParallelProgram
from pp.core.robot import get_system_state, get_global_var, set_io
from pp.core.basic import get_list


class SecurityZone(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_security_zone_judge(self):
        sec_zone1_calc_ref = get_global_var('secZone1_calcRef')
        sec_zone2_cal_cref = get_global_var('secZone2_calcRef')
        ref1_x = get_list(sec_zone1_calc_ref, 0)
        ref1_y = get_list(sec_zone1_calc_ref, 1)
        ref1_z = get_list(sec_zone1_calc_ref, 2)
        ref2_x = get_list(sec_zone2_cal_cref, 0)
        ref2_y = get_list(sec_zone2_cal_cref, 1)
        ref2_z = get_list(sec_zone2_cal_cref, 2)
        while True:
            tcp_pose = get_system_state(SystemStateEnum.TCP_POSE)
            tcp_x = get_list(tcp_pose, 0)
            tcp_y = get_list(tcp_pose, 1)
            tcp_z = get_list(tcp_pose, 2)
            # print(tcp_x)
            # print(tcp_y)
            # print(tcp_z)
            # print(ref1_x)
            # print(ref1_y)
            # print(ref1_z)
            dis1 = (
                (ref1_x - tcp_x) ** 2 + (ref1_y - tcp_y) ** 2 + (ref1_z - tcp_z) ** 2
            ) ** 0.5
            dis2 = (
                (ref2_x - tcp_x) ** 2 + (ref2_y - tcp_y) ** 2 + (ref2_z - tcp_z) ** 2
            ) ** 0.5
            if dis1 > 0.1:
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_0, True)
            elif dis2 > 0.05:
                set_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_1, True)
