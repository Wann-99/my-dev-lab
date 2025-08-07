import argparse
from pathlib import Path
from src.business.rdk_Programs.demo_robot_torque import RobotController, load_config  # 业务类+配置函数
from src.utils.logger_util import CommonLogger  # 日志工具

def main():
    # 1. 解析命令行参数
    parser = argparse.ArgumentParser(description="Robot Torque Reader & Force Control")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config/config.json"),  # 配置文件路径（根据实际调整）
        help="Path to the configuration file (JSON)"
    )
    args = parser.parse_args()

    # 2. 加载配置 & 初始化日志
    config = load_config(args.config)
    logger = CommonLogger()
    logger = logger.get_logger()  # 初始化日志工具

    # 3. 初始化机器人控制器（从配置提取SN）
    robot_sn = config["robot"].get("robot_sn")
    if not robot_sn:
        logger.error("Robot SN not found in config file!")
        return

    robot_controller = RobotController(robot_sn, config, logger)

    # 4. 执行业务流程（示例：循环10次）
    try:
        print("1111")
        #  for _ in range(1, 10):
        #     robot_controller.execute_plan()
    except Exception as e:
        logger.error(f"Execution failed: {str(e)}", exc_info=True)

if __name__ == "__main__":
    main()