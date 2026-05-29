from pp.core.basic import (
    get_list,
    to_number,
    wait_ms, concat_string)

from pp.enums import (
    SystemStateEnum,
    CoordinateSystemEnum,
    CoordinateNameEnum, MetricSystemEnum, GPIOEnum, GPIOOutPortEnum, ModbusTCPOutputEnum
)
from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting

from pp.core.robot import (

    get_io, get_global_var, get_system_state, clear_fault
)


class PrintVairable(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)


    def pp_print_vairable(self):
        while True:
            if get_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_15) == 1:
                pick_pose = get_global_var("PickPose_G")
                obj_x = get_list(pick_pose, 0),
                obj_y = get_list(pick_pose, 1),
                obj_z = get_list(pick_pose, 2),
                obj_rx = get_list(pick_pose, 3),
                obj_ry = get_list(pick_pose, 4),
                obj_rz = get_list(pick_pose, 5),
                pose = concat_string("PickPose: ",obj_x,", ", obj_y,", ", obj_z,", ", obj_rx,", ", obj_ry,", ",obj_rz)
                print(pose)
                wait_ms(1000)
            else:
                self.func_enter_silent_mode()

    def func_enter_silent_mode(self):
        while not get_io(GPIOEnum.SYSTEM, GPIOOutPortEnum.GPIO_OUT_15) == 1:
            if get_system_state(SystemStateEnum.IS_FAULT):
                clear_fault()
            wait_ms(30)