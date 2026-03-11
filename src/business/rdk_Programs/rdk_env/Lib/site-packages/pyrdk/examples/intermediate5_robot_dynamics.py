import argparse

import spdlog

from pyrdk.core.model import Model
from pyrdk.core.plan import Plan
from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================
    # Parse arguments
    argparser = argparse.ArgumentParser()
    argparser.add_argument(
        "robot_ip",
        help="IP of the robot to connect. e.g. 192.168.2.10",
    )
    args = argparser.parse_args()

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial runs the integrated dynamics engine to obtain "
        "robot Jacobian, mass matrix, and gravity torques. Also checks reachability of a Cartesian "
        "pose.\n"
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

        # Robot Dynamics
        # ==========================================================================================
        # Initialize dynamics engine
        model = Model(robot)

        # Step dynamics engine 5 times
        for i in range(5):
            # Update robot model in dynamics engine
            model.update(robot.joint_link_positions, robot.joint_motor_velocities)

            # Compute gravity vector
            g = model.gravity_vector

            # Compute mass matrix
            M = model.mass_matrix

            # Compute Jacobian
            J = model.jacobian("flange")

            # Print result
            logger.info("g = ")
            print(g, flush=True)
            logger.info("M = ")
            print(M, flush=True)
            logger.info("J = ")
            print(J, flush=True)
            print()

        # Check reachability of a Cartesian pose based on current pose
        pose_to_check = robot.tcp_pose.copy()
        pose_to_check[0] += 0.1
        logger.info(f"Checking reachability of Cartesian pose {pose_to_check}")
        result = model.reachable(pose_to_check, robot.joint_link_positions, True)
        logger.info(f"Got a result: reachable = {result[0]}, IK solution = {result[1]}")

    except Exception as e:
        logger.error(str(e))


if __name__ == "__main__":
    main()
