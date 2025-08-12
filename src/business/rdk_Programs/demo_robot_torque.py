#!/usr/bin/env python
"""
业务脚本：机器人扭矩读取与力控流程示例
重构点：
1. 规范导入路径（基于项目根目录）
2. 解耦配置加载与业务逻辑
3. 依赖工具类迁移到 `src/utils/`
4. 日志工具改用重构后的 `common_logger`
"""

import time
import json
from pathlib import Path
from typing import Dict, Any
# 项目级导入（根据重构后目录调整）
from src.utils.logger_util import CommonLogger  # 替换原spdlog，假设已重构日志工具
from src.utils.tool_utils import get_current_tool_parameters  # 迁移后的工具函数
from src.data.csv_utils import DataWriter  # 迁移后的CSV工具
from src.utils.flexivrdk_helper import FlexivRdkHelper  # 新增SDK封装类（可选，建议解耦SDK依赖）

__copyright__ = "Copyright (C) Ltd.wj All Rights Reserved."
__author__ = "wj"


class RobotController:
    """
    机器人控制类：封装机器人执行逻辑，依赖重构后的工具类
    职责：业务流程编排 + 状态管理
    """

    def __init__(self, robot_sn: str, config: dict, logger: CommonLogger()):
        """
        初始化机器人控制器
        :param robot_sn: 机器人序列号
        :param config: 完整配置字典（含robot/parameters等）
        :param logger: 日志工具实例
        """
        self.config_robot = config.get("robot", {})
        self.config_parameters = config.get("parameters", {})

        self.logger = logger  # 假设LoggerUtil返回spdlog或标准logging对象

        # 解耦第三方SDK：用Helper类封装（推荐）
        self.robot_helper = FlexivRdkHelper(robot_sn, self.logger)
        self.tool = self.robot_helper.get_tool()  # 按需封装Tool操作
        self.robot_helper


    def print_robot_force(self, data: list, index: int) -> float | None:
        """工具函数：安全获取机器人力传感器数据"""
        return data[index] if index < len(data) else None

    def execute_primitive(self, primitive_name: str, parameters: dict = None, properties: dict = None):
        """
        封装机器人Primitive执行逻辑
        :param primitive_name: Primitive名称
        :param parameters: 执行参数（默认空字典）
        :param properties: 执行属性（默认空字典）
        """
        self.logger.info(f"Executing primitive: {primitive_name}")
        self.robot_helper.execute_primitive(primitive_name, parameters or {}, properties or {})

    def wait_reach_target(self):
        """等待机器人到达目标位置"""
        while not self.robot_helper.get_primitive_states().get("reachedTarget", False):
            time.sleep(0.001)
        self.logger.info("Reached target position")

    def wait_time_period(self, seconds: float) -> float:
        """等待时间周期（重构命名，符合PEP8）"""
        while not self.robot_helper.get_primitive_states().get("timePeriod") > seconds:
            time.sleep(0.001)
        self.logger.info("Time period reached")
        return self.robot_helper.get_primitive_states().get("timePeriod")

    def wait_terminated(self):
        """等待Primitive终止"""
        while not self.robot_helper.get_primitive_states().get("terminated") is True:
            time.sleep(0.001)
        self.logger.info("Primitive terminated")

    def wait_busy(self):
        """等待传感器零位校准完成"""
        while self.robot_helper.is_busy():
            time.sleep(0.001)
        self.logger.info("Sensor zero calibration completed")

    def stop(self):
        """停止机器人并切换到IDLE模式"""
        self.robot_helper.stop()
        self.logger.info("Robot stopped and set to IDLE mode")

    def execute_plan(self):
        """
        核心业务流程：机器人工具切换、运动控制、力控逻辑
        重构点：
        1. 数据写入解耦到DataWriter
        2. 配置依赖从全局改为实例属性
        3. 第三方SDK操作通过Helper类封装
        """
        writer = DataWriter("demo_read_robot_torque", False)
        try:
            # 工具切换（示例：解耦后逻辑）
            self.robot_helper.switch_mode(self.robot_helper.Mode.IDLE)
            self.tool.switch("tool1_copy")
            self.robot_helper.switch_mode(self.robot_helper.Mode.NRT_PRIMITIVE_EXECUTION)

            # 执行MoveComp（示例：参数从配置读取）
            self.execute_primitive(
                "MoveComp",
                {
                    "target": self.robot_helper.build_coord(
                        self.config_robot["grip_pose"],
                        self.config_robot["grip_pose_angle"],
                        ["WORLD", "WORLD_ORIGIN"],
                        self.config_robot.get("prefer_JntPos_grip")
                    ),
                    "waypoints": [
                        self.robot_helper.build_coord(
                            self.config_robot["grip_up_pose"],
                            self.config_robot["grip_pose_angle"],
                            ["WORLD", "WORLD_ORIGIN"],
                            self.config_robot.get("prefer_JntPos_grip")
                        )
                    ],
                    "vel": self.config_robot["vel"],
                    "acc": self.config_robot["acc"],
                    "jerck": self.config_robot["jerk"],
                    "zoneRadius": self.config_robot["zone_Radius"],
                    "configOptObj": self.config_robot["config_OptObj"]
                }
            )
            self.wait_reach_target()

            # 力传感器归零
            self.execute_primitive("ZeroFTSensor", {})
            self.wait_busy()

            # 执行Hold逻辑（示例）
            self.execute_primitive("Hold")
            static_time = self.wait_time_period(self.config_parameters["seconds"])

            # 获取力传感器数据（解耦后）
            wrench_tcp = self.robot_helper.get_ext_wrench_in_tcp()
            mx = self.print_robot_force(wrench_tcp, 3)
            my = self.print_robot_force(wrench_tcp, 4)
            weight = my / self.config_parameters["eccentric_distance"] / 9.8 * 1000

            # 工具参数获取（解耦后）
            tool_params = get_current_tool_parameters(self.robot_helper, self.robot_helper.Mode)
            mass = tool_params.get('mass')
            tcp_location = tool_params.get('tcp_location')

            # 数据写入（示例：解耦后逻辑）
            if writer.is_new_file:
                writer.write_data(
                    self.config_robot["grip_pose"],
                    self.config_parameters["eccentric_distance"],
                    mass,
                    self.config_parameters["material_weight"],
                    static_time,
                    self.config_robot["vel"],
                    self.config_robot["acc"],
                    self.config_robot["jerk"],
                    mx,
                    my,
                    weight,
                    new_file=True
                )
            else:
                writer.write_data(
                    self.config_robot["grip_pose"],
                    self.config_parameters["eccentric_distance"],
                    mass,
                    self.config_parameters["material_weight"],
                    static_time,
                    self.config_robot["vel"],
                    self.config_robot["acc"],
                    self.config_robot["jerk"],
                    mx,
                    my,
                    weight,
                    new_file=False
                )

        except Exception as e:
            self.logger.error(f"Execution failed: {str(e)}", exc_info=True)
            raise  # 向上层抛出异常，由调用方决定是否终止
        finally:
            self.stop()

def load_config(config_path: Path) -> Dict:
    """通用配置加载函数（独立提取）"""
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file {config_path} not found.")
    with config_path.open('r') as f:
        return json.load(f)