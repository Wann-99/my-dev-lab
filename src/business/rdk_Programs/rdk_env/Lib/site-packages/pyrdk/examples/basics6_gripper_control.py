import sys
import threading
import time

import spdlog

from pyrdk.core.gripper import Gripper
from pyrdk.core.tool import Tool
from pyrdk.enums import GripperNameEnum
from pyrdk.robot import Robot


def print_gripper_states(gripper, logger, stop_event):
    """
    Print gripper states data @ 1Hz.

    """
    while not stop_event.is_set():
        # Print all gripper states, round all float values to 2 decimals
        logger.info("Current gripper states:")
        gripper.get_gripper_states()
        print(f"width: {round(gripper.width, 2)}")
        print(f"force: {round(gripper.force, 2)}")
        print(f"is_moving: {gripper.is_moving()}")
        print("", flush=True)
        time.sleep(1)


def main():
    # Create an event to signal the thread to stop
    stop_event = threading.Event()

    # Program Setup
    # ==============================================================================================

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial does position and force (if available) "
        "control of grippers supported by Flexiv.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="192.168.2.20")

        # Enable the robot and wait for the robot to become operational
        logger.info("Enabling robot ...")
        robot.enable()
        logger.info("Robot is now operational")

        # Gripper Control
        # ==========================================================================================
        # Instantiate gripper
        gripper = Gripper(name=GripperNameEnum.GripperFlexivModbus, robot=robot)

        # Instantiate tool. Gripper is categorized as both a device and a tool. The
        # device attribute allows a gripper to be interactively controlled by the user; whereas the
        # tool attribute tells the robot to account for its mass properties and TCP location.
        tool = Tool(name="Flexiv-GN01", robot=robot)

        # Enable the specified gripper as a device. This is equivalent to enabling the specified
        # gripper in Flexiv Elements -> Settings -> Device
        logger.info(f"Enabling gripper [{gripper.name}]")
        gripper.enable()

        # Print parameters of the enabled gripper
        logger.info("Gripper params:")
        print(f"name: {gripper.name}")
        print(f"min_width: {gripper.min_width}")
        print(f"max_width: {gripper.max_width}")
        print(f"min_force: {gripper.min_force}")
        print(f"max_force: {gripper.max_force}")
        print(f"min_vel: {gripper.min_vel}")
        print(f"max_vel: {gripper.max_vel}")
        print("", flush=True)

        # Switch robot tool to gripper so the gravity compensation and TCP location is updated
        logger.info(f"Switching robot tool to [{tool.name}]")
        robot.switch_tool(tool.name)

        # User needs to determine if this gripper requires manual initialization
        logger.info(
            "Manually trigger initialization for the gripper now? Choose Yes if it's a 48v Grav "
            "gripper"
        )
        print("[1] No, it has already initialized automatically when power on")
        print("[2] Yes, it does not initialize itself when power on")
        choice = int(input(""))

        # Trigger manual initialization based on input
        if choice == 1:
            logger.info("Skipped manual initialization")
        elif choice == 2:
            gripper.init(init=True)
            # User determines if the manual initialization is finished
            logger.info(
                "Triggered manual initialization, press Enter when the initialization is finished to continue"
            )
            input()
        else:
            logger.error("Invalid choice")
            return 1

        # Start a separate thread to print gripper states
        print_thread = threading.Thread(
            target=print_gripper_states, args=[gripper, logger, stop_event]
        )
        print_thread.start()

        # Position control
        logger.info("Closing gripper")
        gripper.move(0.01, 0.1, 20)
        time.sleep(2)
        logger.info("Opening gripper")
        gripper.move(0.09, 0.1, 20)
        time.sleep(2)

        # Stop
        logger.info("Closing gripper")
        gripper.move(0.01, 0.1, 20)
        time.sleep(0.5)
        logger.info("Stopping gripper")
        gripper.stop()
        time.sleep(2)
        logger.info("Closing gripper")
        gripper.move(0.01, 0.1, 20)
        time.sleep(2)
        logger.info("Opening gripper")
        gripper.move(0.09, 0.1, 20)
        time.sleep(0.5)
        logger.info("Stopping gripper")
        gripper.stop()
        time.sleep(2)

        # Force control, if available (sensed force is not zero)
        gripper.get_gripper_states()
        if abs(gripper.force) > sys.float_info.epsilon:
            logger.info("Gripper running zero force control")
            gripper.grasp(0)
            # Exit after 10 seconds
            time.sleep(10)

        # Finished
        gripper.stop()

        # Stop all threads
        logger.info("Stopping print thread")
        stop_event.set()
        print_thread.join()
        logger.info("Print thread exited")
        logger.info("Program finished")

    except Exception as e:
        logger.error(str(e))


if __name__ == "__main__":
    main()
