import sys
from pathlib import Path

LIB_PATH = Path("../libs")  # 假设放到libs目录
sys.path.append(str(LIB_PATH.resolve()))

import time
import spdlog
import flexivrdk
from typing import Dict, Any

class FlexivRdkHelper:
    """
    Flexiv RDK SDK封装类：解耦第三方依赖，方便Mock和测试
    职责：封装机器人模式切换、Primitive执行、状态获取
    """
    class Mode:
        """内置模式常量（映射flexivrdk.Mode）"""
        IDLE = flexivrdk.Mode.IDLE
        NRT_PRIMITIVE_EXECUTION = flexivrdk.Mode.NRT_PRIMITIVE_EXECUTION

    def __init__(self, robot_sn: str, logger: spdlog.Logger):
        self.robot = flexivrdk.Robot(robot_sn)
        self.logger = logger
        self._initialize_robot()

    def _initialize_robot(self):
        """机器人初始化（故障清除、使能逻辑）"""
        if self.robot.fault():
            self.logger.warn("Clearing robot fault...")
            if not self.robot.clear_fault():
                raise RuntimeError("Failed to clear robot fault.")
            self.logger.info("Robot fault cleared.")

        self.logger.info("Enabling robot...")
        self.robot.enable()
        while not self.robot.operational():
            time.sleep(0.1)
        self.logger.info("Robot is operational.")

    def switch_mode(self, mode: Mode):
        """切换机器人模式"""
        self.robot.switch_mode(mode)

    def execute_primitive(self, primitive_name: str, parameters: Dict, properties: Dict):
        """执行Primitive"""
        self.robot.execute_primitive(primitive_name, parameters, properties)

    def get_primitive_states(self) -> Dict[str, Any]:
        """获取Primitive状态"""
        return self.robot.primitive_states()

    def is_busy(self) -> bool:
        """判断机器人是否繁忙"""
        return self.robot.busy()

    def stop(self):
        """停止机器人"""
        self.robot.stop()

    def build_coord(self, *args, **kwargs) -> flexivrdk.Coord:
        """封装Coord构建逻辑（示例）"""
        return flexivrdk.Coord(*args, **kwargs)

    def get_ext_wrench_in_tcp(self) -> list:
        """获取TCP力传感器数据"""
        return self.robot.states().ext_wrench_in_tcp

    def get_tool(self) -> flexivrdk.Tool:
        """获取Tool实例"""
        return flexivrdk.Tool(self.robot)