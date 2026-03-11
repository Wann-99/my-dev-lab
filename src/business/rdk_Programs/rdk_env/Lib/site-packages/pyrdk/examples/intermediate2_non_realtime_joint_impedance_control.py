import argparse
import math
import time

import numpy as np
import spdlog

from pyrdk.core.plan import Plan
from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================
    # Parse arguments
    argparser = argparse.ArgumentParser()
    # Required arguments
    argparser.add_argument(
        "robot_ip",
        help="IP of the robot to connect. e.g. 192.168.2.20",
    )
    argparser.add_argument(
        "frequency", help="Command frequency, 1 to 100 [Hz]", type=int
    )
    # Optional arguments
    argparser.add_argument(
        "--hold",
        action="store_true",
        help="Robot holds current joint positions, otherwise do a sine-sweep",
    )
    args = argparser.parse_args()

    # Check if arguments are valid
    frequency = args.frequency
    assert frequency >= 1 and frequency <= 100, "Invalid <frequency> input"

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial runs non-real-time joint impedance control to "
        "hold or sine-sweep all robot joints.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(args.robot_ip)

        # Enable the robot and wait for the robot to become operational
        logger.info("Enabling robot ...")
        robot.enable()
        logger.info("Robot is now operational")

        # Move robot to home pose
        logger.info("Moving to home pose")
        robot.execute_plan(plan=Plan("PLAN-Home"))

        # Non-real-time Joint Impedance Control
        # ==========================================================================================

        period = 1.0 / frequency
        loop_counter = 0
        logger.info(
            f"Sending command to robot at {frequency} Hz, or {period} seconds interval"
        )

        # Use current robot joint positions as initial positions
        init_pos = robot.joint_link_positions.copy()
        logger.info(f"Initial positions set to: {init_pos}")

        # Robot joint degrees of freedom
        DoF = robot.DoF

        # Initialize target vectors
        target_pos = init_pos.copy()
        target_vel = [0.0] * DoF

        # Joint motion constraints
        MAX_VEL = [114.5916] * DoF
        MAX_ACC = [171.8873] * DoF

        # Joint sine-sweep amplitude [deg]
        SWING_AMP = 5.7296

        # TCP sine-sweep frequency [Hz]
        SWING_FREQ = 0.3

        # Send command periodically at user-specified frequency
        while True:
            # Use sleep to control loop period
            time.sleep(period)

            # Monitor fault on the connected robot
            if robot.is_fault():
                raise Exception("Fault occurred on the connected robot, exiting ...")

            # Sine-sweep all joints
            if not args.hold:
                for i in range(DoF):
                    target_pos[i] = init_pos[i] + SWING_AMP * math.sin(
                        2 * math.pi * SWING_FREQ * loop_counter * period
                    )
            # Otherwise all joints will hold at initial positions

            # Reduce stiffness to half of nominal values after 5 seconds
            if loop_counter == 5 / period:
                stiffness = np.multiply(robot.joint_nominal_stiffness, 0.5).tolist()
                robot.joint_impedance_stiffness = stiffness
                logger.info(f"Joint stiffness set to {stiffness}")

            # Reset impedance properties to nominal values after another 5 seconds
            if loop_counter == 10 / period:
                robot.joint_impedance_stiffness = robot.joint_nominal_stiffness
                logger.info("Joint impedance properties are reset")

            (
                robot.send_joint_position_with_impedance(
                    positions=target_pos,
                    velocities=target_vel,
                    max_vel=MAX_VEL,
                    max_acc=MAX_ACC,
                )
            )

            # Increment loop counter
            loop_counter += 1

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
