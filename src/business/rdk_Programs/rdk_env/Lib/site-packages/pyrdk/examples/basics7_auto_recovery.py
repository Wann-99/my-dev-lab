import spdlog

from pyrdk.exceptions import RobotInRecoveryException
from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================
    # Parse arguments

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial runs an automatic recovery process if the "
        "robot's safety system is in recovery state. See flexiv::rdk::Robot::recovery() and RDK "
        "manual for more details.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="192.168.2.20")
        try:
            # Enable the robot and wait for the robot to become operational
            logger.info("Enabling robot ...")
            robot.enable()

        except RobotInRecoveryException:
            # Run Auto-recovery
            # ==========================================================================================

            # Run automatic recovery if the system is in recovery state, the involved joints will start
            # to move back into allowed position range
            robot.run_auto_recovery()

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
