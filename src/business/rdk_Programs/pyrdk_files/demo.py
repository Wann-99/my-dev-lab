import spdlog

from pyrdk.robot import Robot

import time

def print_robot_info(robot):
    print("Robot version: {}".format(robot._rca_version))
    print("Robot serial number: {}".format(robot.arm_serial_number))

def print_robot_states(robot, logger):
    """
    Print robot states data @ 1Hz.

    """
    # Print all robot states, round all float values to 2 decimals
    logger.info("Current robot wrench:")

    print("{")
    print(f"ext_wrench_in_tcp: {robot.ext_wrench_in_tcp}")
    print(f"ext_wrench_in_world: {robot.ext_wrench_in_world}")
    print("}", flush=True)

    time.sleep(1)

def main():
    logger = spdlog.ConsoleLogger("Example")

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="192.168.100.1")

        # Enable the robot and wait for the robot to become operational
        logger.info("Enabling robot ...")
        robot.enable()
        logger.info("Robot is now operational")
        print_robot_states(robot,logger)
    except Exception as e:
        # Print exception error message
        logger.error(str(e))




if __name__ == "__main__":
    main()
