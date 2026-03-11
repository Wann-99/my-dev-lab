import argparse
import math
import time

import numpy as np  # pip install numpy
import spdlog  # pip install spdlog

from pyrdk.core.plan import Plan
from pyrdk.core.primitives.basic_force_control import BasicForceControl
from pyrdk.robot import Robot

# Global constants
# ==================================================================================================
# TCP sine-sweep amplitude [m]
SWING_AMP = 0.1

# TCP sine-sweep frequency [Hz]
SWING_FREQ = 0.3

# Pressing force to apply during the unified motion-force control [N]
PRESSING_FORCE = 5.0

# Cartesian linear velocity used to search for contact [m/s]
SEARCH_VELOCITY = 0.02

# Maximum distance to travel when searching for contact [m]
SEARCH_DISTANCE = 1.0

# Maximum contact wrench during contact search for soft contact
MAX_WRENCH_FOR_CONTACT_SEARCH = [10.0, 10.0, 10.0, 3.0, 3.0, 3.0]


def main():
    # Program Setup
    # ==============================================================================================
    # Parse arguments
    argparser = argparse.ArgumentParser()
    # Required arguments
    argparser.add_argument(
        "robot_ip",
        help="IP of the robot to connect. e.g. 192.168.2.10",
    )
    argparser.add_argument(
        "frequency", help="Command frequency, 1 to 100 [Hz]", type=int
    )
    # Optional arguments
    argparser.add_argument(
        "--TCP",
        action="store_true",
        help="Use TCP frame as reference frame for force control, otherwise use world frame",
    )
    argparser.add_argument(
        "--polish",
        action="store_true",
        help="Run a simple polish motion along XY plane in world frame, otherwise hold robot motion in non-force-control axes",
    )
    args = argparser.parse_args()

    # Check if arguments are valid
    frequency = args.frequency
    assert frequency >= 1 and frequency <= 100, "Invalid <frequency> input"

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial runs non-real-time Cartesian-space unified "
        "motion-force control. The Z axis of the chosen reference frame will be activated for "
        "explicit force control, while the rest axes in the same reference frame will stay motion "
        "controlled.\n"
    )

    # The reference frame to use, see Robot::SendCartesianMotionForce() for more details
    force_ctrl_frame_is_world = True
    if args.TCP:
        logger.info("Reference frame used for force control: robot TCP frame")
        force_ctrl_frame_is_world = False
    else:
        logger.info("Reference frame used for force control: robot world frame")

    # Whether to enable polish motion
    if args.polish:
        logger.info(
            "Robot will run a polish motion along XY plane in robot world frame"
        )
    else:
        logger.info("Robot will hold its motion in all non-force-controlled axes")

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

        # Zero Force-torque Sensor
        # =========================================================================================
        pt_zeroftsensor = BasicForceControl.ZeroFTSensor(
            conditions={BasicForceControl.ZeroFTSensor.State.Terminated: 1}
        )
        # IMPORTANT: must zero force/torque sensor offset for accurate force/torque measurement
        # WARNING: during the process, the robot must not contact anything, otherwise the result
        # will be inaccurate and affect following operations
        logger.warn(
            "Zeroing force/torque sensors, make sure nothing is in contact with the robot"
        )

        robot.execute_primitive(pt_zeroftsensor)
        logger.info("Sensor zeroing complete")

        # Search for Contact
        # =========================================================================================
        # NOTE: there are several ways to do contact search, such as using primitives, or real-time
        # and non-real-time direct motion controls, etc. Here we use non-real-time direct Cartesian
        # control for example.
        logger.info("Searching for contact ...")

        # Set initial pose to current TCP pose
        init_pose = robot.tcp_pose.copy()
        logger.info(
            f"Initial TCP pose set to {init_pose} (position 3x1, rotation (euler) 3x1)"
        )

        # Use non-real-time mode to make the robot go to a set point with its own motion generator
        # Search for contact with max contact wrench set to a small value for making soft contact
        robot.max_contact_wrench = MAX_WRENCH_FOR_CONTACT_SEARCH

        # Set target point along -Z direction and expect contact to happen during the travel
        target_pose = init_pose.copy()
        target_pose[2] -= SEARCH_DISTANCE

        # Send target point to robot to start searching for contact and limit the velocity. Keep
        # target wrench 0 at this stage since we are not doing force control yet
        robot.send_cartesian_motion_force(
            pose=target_pose,
            wrench=[0] * 6,
            velocity=[0] * 6,
            max_linear_vel=SEARCH_VELOCITY,
        )

        # Use a while loop to poll robot states and check if a contact is made
        is_contacted = False
        while not is_contacted:
            # Compute norm of sensed external force applied on robot TCP
            ext_force = np.array(
                [
                    robot.ext_wrench_in_world[0],
                    robot.ext_wrench_in_world[1],
                    robot.ext_wrench_in_world[2],
                ]
            )

            # Contact is considered to be made if sensed TCP force exceeds the threshold
            if np.linalg.norm(ext_force) > PRESSING_FORCE:
                is_contacted = True
                logger.info("Contact detected at robot TCP")

            # Check at 1ms interval
            time.sleep(0.001)

        # Configure Force Control
        # =========================================================================================

        # Set force control reference frame based on program argument. See function doc for more
        # details
        robot.force_control_frame_root_coord_type = force_ctrl_frame_is_world

        # Set which Cartesian axis(s) to activate for force control. See function doc for more
        # details. Here we only activate Z axis
        robot.force_control_axis_enabled_axes = [
            False,
            False,
            True,
            False,
            False,
            False,
        ]

        # Uncomment the following line to enable passive force control, otherwise active force
        # control is used by default. See function doc for more details
        # robot.setPassiveForceControl(True)

        # NOTE: motion control always uses robot world frame, while force control can use
        # either world or TCP frame as reference frame

        # Start Unified Motion Force Control
        # =========================================================================================
        # Disable max contact wrench regulation. Need to do this AFTER the force control in Z axis
        # is activated (i.e. motion control disabled in Z axis) and the motion force control mode
        # is entered, this way the contact force along Z axis is explicitly regulated and will not
        # spike after the max contact wrench regulation for motion control is disabled
        robot.max_contact_wrench = [float("inf")] * 6

        # Update initial pose to current TCP pose
        init_pose = robot.tcp_pose.copy()
        logger.info(
            f"Initial TCP pose set to {init_pose} (position 3x1, rotation (euler) 3x1)"
        )

        # Periodic Task
        # =========================================================================================
        # Set loop period
        period = 1.0 / frequency
        logger.info(
            f"Sending command to robot at {frequency} Hz, or {period} seconds interval"
        )

        # Periodic loop counter
        loop_counter = 0

        # Send command periodically at user-specified frequency
        while True:
            # Use sleep to control loop period
            time.sleep(period)

            # Monitor fault on the connected robot
            if robot.is_fault():
                raise Exception("Fault occurred on the connected robot, exiting ...")

            # Initialize target pose to initial pose
            target_pose = init_pose.copy()

            # Set Fz according to reference frame to achieve a "pressing down" behavior
            Fz = 0.0
            if force_ctrl_frame_is_world:
                Fz = PRESSING_FORCE
            else:
                Fz = -PRESSING_FORCE
            target_wrench = [0.0, 0.0, Fz, 0.0, 0.0, 0.0]

            # Apply constant force along Z axis of chosen reference frame, and do a simple polish
            # motion along XY plane in robot world frame
            if args.polish:
                # Create motion command to sine-sweep along Y direction
                target_pose[1] = init_pose[1] + SWING_AMP * math.sin(
                    2 * math.pi * SWING_FREQ * loop_counter * period
                )
                # Command target pose and target wrench
                robot.send_cartesian_motion_force(
                    pose=target_pose, wrench=target_wrench
                )
            # Apply constant force along Z axis of chosen reference frame, and hold motions in all
            # other axes
            else:
                # Command initial pose and target wrench
                robot.send_cartesian_motion_force(pose=init_pose, wrench=target_wrench)

            # Increment loop counter
            loop_counter += 1

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
