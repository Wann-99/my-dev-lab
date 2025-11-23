from pp.core.robot import get_system_state
from pp.enums import SystemStateEnum
from pp.settings import RobotSetting

from MyPP.clearfault_test import ClearFaultTest
from MyPP.setting_robot import SettingRobot
from MyPP.control_gripper import ControlGripper
from MyPP.security_zone import SecurityZone
from MyPP.control_robot import ControlRobot
from MyPP.control_robot_2 import ControlRobot_1
from MyPP.robot_socket import RobotSocket
from MyPP.calculate_location import CalculatePosition


if __name__ == "__main__":

    # 机器人的默认地址是192.168.2.100，可以修改为实际IP地址
    # 如果机器人IP是默认的，则不需要定义RobotSetting对象

    setting = RobotSetting(ip="192.168.2.100")
    # 需继承ParallelProgram类，然后在类中定义函数，函数名必须以pp_开头，类中可以定义多个pp_函数
    # pp程序默认auto_booted为False, auto_looped为False，定义函数时如传入参数，则按照用户定义的参数来配置并行程序
    # 可以添加这两个参数(非必填)
    #     pp = simulation_socket(setting=setting)
    #     pp = simulation_socket()
    #     pp = UsbSensorPP()
    # 在当前目录下生成包含并行程序名称的文件夹(不包含pp_前缀)
    pp = CalculatePosition(setting=setting)
    # pp = CrispyMeat(setting=setting)
    # pp = SettingRobot(setting=setting)
    # pp = ClearFaultTest(setting=setting)
    # pp = ControlGripper(setting=setting)
    # pp = SecurityZone(setting=setting)
    # pp = ControlRobot(setting=setting)
    # pp = ControlRobot_1(setting=setting)
    # pp = RobotSocket(setting=setting)
    # 如果想直接在机器人端运行则可以忽略此步骤
    pp.to_lua(check=False)
    pp.disable()
    # 将并行程序发送到机器人端
    pp.assign()
    # 使能并行程序
    pp.enable()
    # 删除程序
    # pp.remove()
    # 执行并行程序
    pp.start()
