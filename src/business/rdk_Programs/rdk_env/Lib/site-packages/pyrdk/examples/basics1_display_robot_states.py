import threading
import time

import spdlog

from pyrdk.robot import Robot


def print_robot_states(robot, logger, stop_event):
    """
    Print robot states data @ 1Hz.

    """

    while not stop_event.is_set():
        # Print all robot states, round all float values to 2 decimals
        logger.info("Current robot states:")

        print("{")
        print(
            f"joint_link_positions: {robot.joint_link_positions}",
        )
        print(f"joint_motor_positions: {robot.joint_motor_positions}")
        print(f"joint_link_velocities: {robot.joint_link_velocities}")
        print(f"joint_motor_velocities: {robot.joint_motor_velocities}")
        print(f"joint_torques: {robot.joint_torques}")
        print(f"desired_joint_torque: {robot.desired_joint_torque}")
        print(
            f"derivative_of_measured_joint_torques: {robot.derivative_of_measured_joint_torques}"
        )
        print(f"external_joint_torque: {robot.external_joint_torque}")
        print(f"tcp_pose: {robot.tcp_pose}")
        print(f"tcp_velocities: {robot.tcp_velocities}")
        print(f"flange_pose: {robot.flange_pose}")
        print(f"ft_sensor_raw_reading: {robot.ft_sensor_raw_reading}")
        print(f"ext_wrench_in_tcp: {robot.ext_wrench_in_tcp}")
        print(f"ext_wrench_in_world: {robot.ext_wrench_in_world}")
        print(f"ext_wrench_in_tcp_raw: {[robot.ext_wrench_in_tcp_raw]}")
        print(f"ext_wrench_in_world_raw: {robot.ext_wrench_in_world_raw}")
        print("}", flush=True)

        # Print digital inputs
        logger.info("Current digital inputs:")
        print(robot.digital_inputs)
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
        ">>> Tutorial description <<<\nThis tutorial does the very first thing: check connection "
        "with the robot server and print received robot states.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="127.0.0.1")

        # Enable the robot and wait for the robot to become operational
        logger.info("Enabling robot ...")
        robot.enable()
        logger.info("Robot is now operational")

    except Exception as e:
        # Print exception error message
        logger.error(str(e))

    # Print States
    # =============================================================================
    # Thread for printing robot states
    print_thread = threading.Thread(
        target=print_robot_states, args=[robot, logger, stop_event]
    )
    print_thread.start()

    # Use main thread to catch keyboard interrupt and exit thread
    try:
        while not stop_event.is_set():
            time.sleep(0.1)
    except KeyboardInterrupt:
        # Send signal to exit thread
        logger.info("Stopping print thread")
        stop_event.set()

    # Wait for thread to exit
    print_thread.join()
    logger.info("Print thread exited")


if __name__ == "__main__":
    main()
