from pp.core.basic import wait_ms, append_list, concat_string, join_list, set_list

from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import SystemStateEnum
from pp.core.robot import (
    clear_fault,
    fault,
    get_system_state,
)


class ClearFaultTest(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_clear_fault(self):
        """
        清除系统故障的完整方法，合并了伺服状态检查和故障清除功能
        流程：
        1. 检查伺服状态
        2. 如果存在故障则尝试清除
        3. 循环直到故障清除或伺服状态异常
        """
        # 初始化状态变量
        servo_off_logged = False  # 新增：用于记录伺服断电日志是否已打印
        message_list = []
        while True:  # 保持程序一直运行
            # 获取伺服上电状态
            servo_on = get_system_state(SystemStateEnum.IS_SERVO_ON)
            # set_list(message_list, 0, "机器人上电状态：")
            # set_list(message_list, 1, servo_on)
            # print(join_list(message_list, ","))
            # 检查伺服状态
            if not servo_on:
                if not servo_off_logged:  # 只在第一次检测到断电时打印日志
                    print("机器人报错未上电")
                    servo_off_logged = True
                    error_printed = True  # 重置错误打印标志
                continue  # 跳过后续处理，继续循环等待
            # 伺服已上电时的处理
            if servo_off_logged:  # 如果之前是断电状态
                servo_off_logged = False  # 重置断电标志
                print("机器人上电恢复")  # 可选：记录上电恢复日志
            # 检查故障状态
            if get_system_state(SystemStateEnum.IS_FAULT):
                # 执行故障清除操作
                clear_fault()
                wait_ms(1)
                # 检查故障状态
                status_fault = get_system_state(SystemStateEnum.IS_FAULT)
                # print("上电状态: ", "get_system_state(SystemStateEnum.IS_SERVO_ON)")
                if not status_fault:
                    print("pp_clear_fault_success")
                    fault_result = status_fault  # 清除成功
                else:
                    print("pp_clear_fault_fail")
                    fault_result = not status_fault  # 清除失败
            else:
                fault_result = False  # 无故障
            # 短暂延迟防止CPU占用过高
            wait_ms(100)


# class fault_test(ParallelProgram):
#     def __init__(self, setting: RobotSetting = RobotSetting()):
#         super().__init__(setting=setting)
#
#     def pp_fault(self):
#         fault("trigger_fault_by_pp")
