import spdlog

from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial clears minor or critical faults, if any, of "
        "the connected robot.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="127.0.0.1")

        # Fault Clearing
        robot.clear_fault()

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
