from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    socket_open,
    socket_recv,
    socket_send,
    socket_connected
)
from pp.core.robot import (
    update_object_pool
)
from pp.core.basic import (
    split_string,
    get_list)


class ConvVisionTrigger(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_conv_vision_trigger(self):
        cam_intr_params = '919.49866 918.7968 648.15015 375.07938 1280 720 0.001'
        cam_extr_params = '0 0 0 0 0 0'
        obj_name = 'Conveyor-SerialPort-1/Vision'
        recv_text = ''
        while True:
            if socket_open(1, '192.168.2.112', 30000) :
                socket_connect = socket_connected(1)
                if  socket_connect:
                    print('Connection success')
                while socket_connect:
                    # if get_io(GPIOEnum.SYSTEM,GPIOInPortEnum.GPIO_IN_0 ) == 1 :
                    if not socket_send(1, 'Trigger') :
                        print('Send fail')
                        break
                    recv_text = socket_recv(1)
                    if recv_text != '' :
                        obj_param = split_string(recv_text, ';')
                        obj_value = get_list(obj_param,1)
                        update_object_pool(obj_name,8 ,obj_value, cam_intr_params, cam_extr_params, 'flange')
                    wait_ms(100)
            else :
                self.func_enter_silent_mode()
        

    def func_enter_silent_mode(self):
        """进入静默模式"""
        print('Loss connection')
        while not socket_open(1, '192.168.2.112', 30000):
            if get_system_state(SystemStateEnum.IS_FAULT):
                clear_fault()
            wait_ms(30)


