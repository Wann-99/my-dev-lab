# import sys
# from pathlib import Path

# LIB_PATH = Path("../libs")  # 假设放到libs目录
# sys.path.append(str(LIB_PATH.resolve()))

import time
import spdlog
import flexivrdk
from typing import Dict, Any, Optional, List
from dataclasses import dataclass


@dataclass
class RobotStatus:
    """机器人状态数据类，封装关键状态信息"""
    is_operational: bool
    current_mode: int
    is_busy: bool
    ext_wrench_in_tcp: List[float]
    primitive_states: Dict[str, Any]


class FlexivRdkHelper:
    """
    Flexiv RDK SDK封装类：解耦第三方依赖，方便Mock和测试
    职责：封装机器人模式切换、Primitive执行、状态获取
    """

    class Mode:
        """内置模式常量（映射flexivrdk.Mode）"""
        IDLE = flexivrdk.Mode.IDLE
        NRT_PRIMITIVE_EXECUTION = flexivrdk.Mode.NRT_PRIMITIVE_EXECUTION
        # 可以根据需要添加更多模式

    def __init__(self, robot_sn: str, logger: spdlog.Logger, max_retry: int = 3):
        """
        初始化Flexiv机器人助手

        :param robot_sn: 机器人序列号
        :param logger: 日志记录器
        :param max_retry: 操作最大重试次数
        """
        self.robot_sn = robot_sn
        self.logger = logger
        self.max_retry = max_retry
        self.robot: Optional[flexivrdk.Robot] = None
        self._initialize_robot()

    def _initialize_robot(self) -> None:
        """机器人初始化（故障清除、使能逻辑），带重试机制"""
        retry_count = 0
        while retry_count < self.max_retry:
            try:
                self.robot = flexivrdk.Robot(self.robot_sn)
                if not self.robot:
                    raise RuntimeError("Failed to create robot instance")

                # 清除故障
                if self.robot.fault():
                    self.logger.warn("Robot has fault, attempting to clear...")
                    if not self.robot.clear_fault():
                        raise RuntimeError("Failed to clear robot fault")
                    self.logger.info("Robot fault cleared successfully")
                    time.sleep(1.0)  # 等待故障清除生效

                # 使能机器人
                self.logger.info("Enabling robot...")
                self.robot.Enable()

                # 等待操作完成，带超时
                timeout = 10.0  # 10秒超时
                start_time = time.time()
                while not self.robot.operational():
                    if time.time() - start_time > timeout:
                        raise TimeoutError("Robot enable timed out")
                    time.sleep(0.1)

                self.logger.info("Robot initialized successfully and is operational")
                return

            except Exception as e:
                retry_count += 1
                self.logger.error(f"Robot initialization attempt {retry_count} failed: {str(e)}")
                if retry_count >= self.max_retry:
                    raise RuntimeError(f"Failed to initialize robot after {self.max_retry} attempts") from e
                time.sleep(2.0)  # 重试前等待

    def switch_mode(self, mode: Mode, timeout: float = 5.0) -> bool:
        """
        切换机器人模式

        :param mode: 目标模式
        :param timeout: 超时时间(秒)
        :return: 是否切换成功
        """
        if not self.robot:
            self.logger.error("Robot instance not initialized")
            return False

        try:
            self.logger.info(f"Switching to mode: {mode}")
            self.robot.switch_mode(mode)

            # 等待模式切换完成
            start_time = time.time()
            while self.robot.mode() != mode:
                if time.time() - start_time > timeout:
                    self.logger.error(f"Failed to switch to mode {mode} within {timeout}s")
                    return False
                time.sleep(0.1)

            self.logger.info(f"Successfully switched to mode: {mode}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to switch mode: {str(e)}")
            return False

    def execute_primitive(self, primitive_name: str,
                          parameters: Dict[str, Any] = None,
                          properties: Dict[str, Any] = None,
                          timeout: float = 10.0) -> bool:
        """
        执行Primitive动作

        :param primitive_name: Primitive名称
        :param parameters: 执行参数
        :param properties: 执行属性
        :param timeout: 超时时间(秒)
        :return: 是否执行成功
        """
        if not self.robot:
            self.logger.error("Robot instance not initialized")
            return False

        try:
            parameters = parameters or {}
            properties = properties or {}

            self.logger.info(f"Executing primitive: {primitive_name} with parameters: {parameters}")
            self.robot.execute_primitive(primitive_name, parameters, properties)

            # 等待Primitive开始执行
            start_time = time.time()
            while not self.is_busy():
                if time.time() - start_time > timeout:
                    self.logger.error(f"Primitive {primitive_name} did not start within {timeout}s")
                    return False
                time.sleep(0.1)

            self.logger.info(f"Primitive {primitive_name} started successfully")
            return True

        except Exception as e:
            self.logger.error(f"Failed to execute primitive {primitive_name}: {str(e)}")
            return False

    def get_primitive_states(self) -> Dict[str, Any]:
        """
        获取Primitive状态

        :return: 状态字典，如果获取失败则返回空字典
        """
        try:
            if not self.robot:
                self.logger.error("Robot instance not initialized")
                return {}
            return self.robot.primitive_states()
        except Exception as e:
            self.logger.error(f"Failed to get primitive states: {str(e)}")
            return {}

    def is_busy(self) -> bool:
        """
        判断机器人是否繁忙

        :return: 机器人是否繁忙，如果获取失败则返回False
        """
        try:
            if not self.robot:
                self.logger.error("Robot instance not initialized")
                return False
            return self.robot.busy()
        except Exception as e:
            self.logger.error(f"Failed to check if robot is busy: {str(e)}")
            return False

    def stop(self, timeout: float = 5.0) -> bool:
        """
        停止机器人操作

        :param timeout: 超时时间(秒)
        :return: 是否停止成功
        """
        if not self.robot:
            self.logger.error("Robot instance not initialized")
            return False

        try:
            self.logger.info("Stopping robot...")
            self.robot.stop()

            # 等待机器人停止
            start_time = time.time()
            while self.is_busy():
                if time.time() - start_time > timeout:
                    self.logger.warn("Robot did not stop within timeout period")
                    return False
                time.sleep(0.1)

            self.logger.info("Robot stopped successfully")
            return True

        except Exception as e:
            self.logger.error(f"Failed to stop robot: {str(e)}")
            return False

    def build_coord(self, *args, **kwargs) -> flexivrdk.Coord:
        """
        封装Coord构建逻辑

        :param args: 位置参数
        :param kwargs: 关键字参数
        :return: 构建的Coord对象
        """
        try:
            return flexivrdk.Coord(*args, **kwargs)
        except Exception as e:
            self.logger.error(f"Failed to build coordinate: {str(e)}")
            raise

    def get_ext_wrench_in_tcp(self) -> List[float]:
        """
        获取TCP力传感器数据

        :return: 六维力数据 [fx, fy, fz, tx, ty, tz]，获取失败则返回空列表
        """
        try:
            if not self.robot:
                self.logger.error("Robot instance not initialized")
                return []
            return self.robot.states().ext_wrench_in_tcp
        except Exception as e:
            self.logger.error(f"Failed to get external wrench in TCP: {str(e)}")
            return []

    def get_tool(self) -> Optional[flexivrdk.Tool]:
        """
        获取Tool实例

        :return: Tool对象，如果获取失败则返回None
        """
        try:
            if not self.robot:
                self.logger.error("Robot instance not initialized")
                return None
            return flexivrdk.Tool(self.robot)
        except Exception as e:
            self.logger.error(f"Failed to get tool instance: {str(e)}")
            return None

    def get_current_mode(self) -> Optional[int]:
        """
        获取当前机器人模式

        :return: 当前模式，如果获取失败则返回None
        """
        try:
            if not self.robot:
                self.logger.error("Robot instance not initialized")
                return None
            return self.robot.mode()
        except Exception as e:
            self.logger.error(f"Failed to get current mode: {str(e)}")
            return None

    def get_status(self) -> RobotStatus:
        """
        获取综合机器人状态

        :return: 包含多种状态信息的RobotStatus对象
        """
        try:
            if not self.robot:
                return RobotStatus(
                    is_operational=False,
                    current_mode=-1,
                    is_busy=False,
                    ext_wrench_in_tcp=[],
                    primitive_states={}
                )

            return RobotStatus(
                is_operational=self.robot.operational(),
                current_mode=self.robot.mode(),
                is_busy=self.robot.busy(),
                ext_wrench_in_tcp=self.robot.states().ext_wrench_in_tcp,
                primitive_states=self.robot.primitive_states()
            )
        except Exception as e:
            self.logger.error(f"Failed to get robot status: {str(e)}")
            return RobotStatus(
                is_operational=False,
                current_mode=-1,
                is_busy=False,
                ext_wrench_in_tcp=[],
                primitive_states={}
            )

    def __del__(self):
        """析构函数，确保机器人安全停止"""
        if self.robot and self.robot.operational():
            try:
                self.logger.info("Cleaning up robot resources...")
                self.stop()
                self.switch_mode(self.Mode.IDLE)
            except Exception as e:
                self.logger.error(f"Error during cleanup: {str(e)}")
