import argparse
import json
from pathlib import Path
from typing import Optional

from src.utils.logger_util import CommonLogger


def _resolve_robot_sn(config: dict, override: Optional[str]) -> str:
    if override:
        return override
    robot_sn = config.get("robot", {}).get("robot_sn")
    if not robot_sn:
        raise ValueError("Robot SN not found in config and no override provided")
    return robot_sn


def _load_config(config_path: Path) -> dict:
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file {config_path} not found.")
    with config_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        prog="flexivrobot",
        description="Unified CLI for Flexiv robot tasks"
    )

    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config/config.json"),
        help="Path to configuration file (JSON)"
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # torque command (demo robot torque and plan execution)
    torque_parser = subparsers.add_parser(
        "torque",
        help="Run demo robot torque flow"
    )
    torque_parser.add_argument("--robot-sn", type=str, help="Override robot serial number")
    torque_parser.add_argument("--loops", type=int, default=1, help="Number of plan executions")

    # collect-force command (force data collection)
    collect_parser = subparsers.add_parser(
        "collect-force",
        help="Collect force data and save to CSV"
    )
    collect_parser.add_argument("--robot-sn", type=str, help="Override robot serial number")
    collect_parser.add_argument("--duration", type=int, help="Collection duration in seconds")
    collect_parser.add_argument("--sampling-rate", type=int, help="Sampling rate in Hz")

    args = parser.parse_args()

    # init logger
    logger = CommonLogger().get_logger()

    try:
        # 惰性导入业务模块，避免 --help 时失败
        config = _load_config(args.config)

        if args.command == "torque":
            from src.business.rdk_Programs.demo_robot_torque import RobotController
            robot_sn = _resolve_robot_sn(config, args.robot_sn)
            controller = RobotController(robot_sn, config, logger)

            logger.info(f"Starting torque demo, loops={args.loops}")
            for _ in range(args.loops):
                controller.execute_plan()
            controller.stop()
            logger.info("Torque demo finished")

        elif args.command == "collect-force":
            from src.business.rdk_Programs.FlexivForceDataCollector import FlexivForceDataCollector
            robot_sn = _resolve_robot_sn(config, args.robot_sn)
            collector = FlexivForceDataCollector(robot_sn, config, logger)
            success, msg = collector.run_collect_and_save(
                duration=args.duration,
                sampling_rate=args.sampling_rate,
            )
            if success:
                logger.info(msg)
            else:
                logger.error(msg)

    except Exception as e:
        logger = CommonLogger().get_logger()  # fallback
        logger.error(f"Command failed: {str(e)}", exc_info=True)


if __name__ == "__main__":
    main()