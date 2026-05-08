# !/usr/bin/env python
"""
业务脚本：机器人力数据采集模块
基于RobotController架构重构，遵循项目设计规范
"""
import time
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# 项目级导入
from src.utils.logger_util import CommonLogger
from src.utils.tool_utils import get_current_tool_parameters
from src.data.csv_utils import DataWriter
from src.utils.flexivrdk_helper import FlexivRdkHelper

__copyright__ = "Copyright (C) Ltd.wj All Rights Reserved."
__author__ = "wj"


class FlexivForceDataCollector:
    """
    力数据采集器：基于RobotController架构实现力数据采集功能
    遵循现有代码设计模式，使用Helper类解耦SDK依赖
    """

    def __init__(self, robot_sn: str, config: dict, logger: CommonLogger):
        """
        初始化力数据采集器

        :param robot_sn: 机器人序列号
        :param config: 完整配置字典
        :param logger: 日志工具实例
        """
        self.config_robot = config.get("robot", {})
        self.config_parameters = config.get("parameters", {})
        self.logger = logger

        # 使用现有Helper类解耦SDK依赖
        self.robot_helper = FlexivRdkHelper(robot_sn, self.logger)
        self.tool = self.robot_helper.get_tool()

        # 数据采集配置
        self.sample_config = self.config_parameters.get("force_collection", {})
        self.default_duration = self.sample_config.get("duration", 10)
        self.default_sampling_rate = self.sample_config.get("sampling_rate", 100)

        # 数据缓存
        self.data_buffer: List[Dict] = []

        self.logger.info("Flexiv force data collector initialized successfully")

    def _get_force_data(self) -> Optional[Dict]:
        """
        获取力传感器数据（内部方法）
        遵循现有代码的数据获取模式

        :return: 包含各轴向力数据的字典，获取失败返回None
        """
        try:
            # 使用Helper类获取力数据，保持解耦
            wrench_tcp = self.robot_helper.get_ext_wrench_in_tcp()

            if len(wrench_tcp) < 6:
                self.logger.warning("Incomplete force data received from sensor")
                return None

            # 获取工具参数（遵循现有代码的数据获取方式）
            tool_params = get_current_tool_parameters(
                self.robot_helper,
                self.robot_helper.Mode.NRT_PRIMITIVE_EXECUTION
            )

            return {
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f"),
                "fx": wrench_tcp[0],
                "fy": wrench_tcp[1],
                "fz": wrench_tcp[2],
                "mx": wrench_tcp[3],
                "my": wrench_tcp[4],
                "mz": wrench_tcp[5],
                "tool_mass": tool_params.get('mass'),
                "tcp_location": tool_params.get('tcp_location')
            }

        except Exception as e:
            self.logger.error(f"Failed to get force data: {str(e)}", exc_info=True)
            return None

    def configure_collection(self, duration: Optional[int] = None, sampling_rate: Optional[int] = None) -> None:
        """
        配置数据采集参数

        :param duration: 采集时长（秒），None则使用配置文件默认值
        :param sampling_rate: 采样频率（Hz），None则使用配置文件默认值
        """
        self.duration = duration if duration is not None else self.default_duration
        self.sampling_rate = sampling_rate if sampling_rate is not None else self.default_sampling_rate

        # 参数验证
        if self.duration <= 0:
            raise ValueError("Collection duration must be positive")
        if self.sampling_rate <= 0:
            raise ValueError("Sampling rate must be positive")

        self.logger.info(
            f"Collection configured - Duration: {self.duration}s, "
            f"Sampling rate: {self.sampling_rate}Hz"
        )

    def start_collection(self) -> Tuple[bool, str]:
        """
        开始力数据采集

        :return: (是否成功, 状态消息)
        """
        if not hasattr(self, 'duration') or not hasattr(self, 'sampling_rate'):
            # 使用默认配置
            self.configure_collection()

        self.data_buffer = []
        interval = 1.0 / self.sampling_rate
        start_time = time.perf_counter()
        end_time = start_time + self.duration

        self.logger.info(f"Starting force data collection for {self.duration} seconds...")

        try:
            # 切换到合适的模式（遵循现有代码的模式切换逻辑）
            current_mode = self.robot_helper.get_mode()
            if current_mode != self.robot_helper.Mode.NRT_PRIMITIVE_EXECUTION:
                self.logger.warning(f"Switching mode from {current_mode} to NRT_PRIMITIVE_EXECUTION")
                self.robot_helper.switch_mode(self.robot_helper.Mode.NRT_PRIMITIVE_EXECUTION)

            # 执行Hold primitive以保持稳定状态
            self.robot_helper.execute_primitive("Hold")

            # 数据采集循环
            while time.perf_counter() < end_time:
                loop_start = time.perf_counter()

                # 获取力数据
                force_data = self._get_force_data()
                if force_data:
                    force_data["elapsed_time"] = round(time.perf_counter() - start_time, 3)
                    self.data_buffer.append(force_data)

                # 控制采样频率
                loop_duration = time.perf_counter() - loop_start
                sleep_time = interval - loop_duration

                if sleep_time > 0:
                    time.sleep(sleep_time)

            self.logger.info(f"Collection completed. Total samples: {len(self.data_buffer)}")
            return True, f"Collection completed successfully. Total samples: {len(self.data_buffer)}"

        except KeyboardInterrupt:
            self.logger.warning("Collection interrupted by user")
            return False, "Collection interrupted by user"
        except Exception as e:
            self.logger.error(f"Collection failed: {str(e)}", exc_info=True)
            return False, f"Collection failed: {str(e)}"
        finally:
            # 恢复原始模式
            if current_mode != self.robot_helper.get_mode():
                self.robot_helper.switch_mode(current_mode)

    def save_data(self, writer: Optional[DataWriter] = None) -> Tuple[bool, str]:
        """
        保存采集的数据

        :param writer: DataWriter实例，None则创建新实例
        :return: (是否成功, 状态消息)
        """
        if not self.data_buffer:
            warning_msg = "No data to save. Please perform collection first."
            self.logger.warning(warning_msg)
            return False, warning_msg

        try:
            # 使用DataWriter类（遵循现有代码的数据写入方式）
            if writer is None:
                # 生成带时间戳的文件名
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                writer = DataWriter(f"force_data_{timestamp}", False)

            # 写入数据头
            if writer.is_new_file:
                headers = list(self.data_buffer[0].keys())
                writer.write_header(headers)

            # 写入数据
            for data_point in self.data_buffer:
                writer.write_data(*data_point.values())

            success_msg = f"Data saved successfully. Total records: {len(self.data_buffer)}"
            self.logger.info(success_msg)
            return True, success_msg

        except Exception as e:
            error_msg = f"Failed to save data: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return False, error_msg

    def run_collect_and_save(self, duration: Optional[int] = None,
                             sampling_rate: Optional[int] = None,
                             writer: Optional[DataWriter] = None) -> Tuple[bool, str]:
        """
        一站式执行采集和保存流程

        :param duration: 采集时长（秒）
        :param sampling_rate: 采样频率（Hz）
        :param writer: DataWriter实例
        :return: (是否成功, 状态消息)
        """
        try:
            self.configure_collection(duration, sampling_rate)
            collect_success, collect_msg = self.start_collection()

            if collect_success:
                save_success, save_msg = self.save_data(writer)
                return save_success, save_msg
            else:
                return False, collect_msg

        except Exception as e:
            error_msg = f"Collection workflow failed: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return False, error_msg


def main():
    """主函数：演示如何使用力数据采集器"""
    # 解析命令行参数（遵循现有代码的参数解析方式）
    import argparse
    parser = argparse.ArgumentParser(description="Flexiv Force Data Collection Tool")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config/config.json"),
        help="Path to configuration file"
    )
    parser.add_argument(
        "--duration",
        type=int,
        help=f"Collection duration in seconds (default: from config)"
    )
    parser.add_argument(
        "--sampling-rate",
        type=int,
        help=f"Sampling rate in Hz (default: from config)"
    )

    args = parser.parse_args()

    # 初始化日志（遵循现有代码的日志初始化方式）
    logger = CommonLogger().get_logger()

    try:
        # 加载配置文件（使用现有函数）
        config = load_config(args.config)

        # 获取机器人SN
        robot_sn = config["robot"].get("robot_sn")
        if not robot_sn:
            raise ValueError("Robot serial number (robot_sn) not found in config")

        # 创建采集器实例
        collector = FlexivForceDataCollector(robot_sn, config, logger)

        # 执行采集
        success, msg = collector.run_collect_and_save(
            duration=args.duration,
            sampling_rate=args.sampling_rate
        )

        if success:
            logger.info(msg)
        else:
            logger.error(msg)

    except Exception as e:
        logger.error(f"Force data collection failed: {str(e)}", exc_info=True)
        exit(1)


def load_config(config_path: Path) -> Dict:
    """通用配置加载函数（直接复用现有代码）"""
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file {config_path} not found.")
    with config_path.open('r') as f:
        return json.load(f)


if __name__ == "__main__":
    main()


