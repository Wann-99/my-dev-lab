import spdlog

from pyrdk.core.primitives.motion import Motion
from pyrdk.core.primitives.workflow import Workflow
from pyrdk.enums import TrajFrameValueEnum
from pyrdk.robot import Robot
from pyrdk.types import CoordinateType, JointPositionType, TrajFrameType, WorldFrameType


def main():
    # Program Setup
    # ==============================================================================================
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial executes several basic robot primitives (unit "
        "skills). For detailed documentation on all available primitives, please see [Flexiv "
        "Primitives](https://www.flexiv.com/primitives/).\n"
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

        # Execute Primitives

        # (1) Go to home pose
        # ------------------------------------------------------------------------------------------
        # All parameters of the "Home" primitive are optional, thus we can skip the parameters and
        # the default values will be used

        pt_home = Workflow.Home(conditions={Workflow.Home.State.ReachedTarget: 1})

        # Send command to robot and wait for reached target
        logger.info("Executing primitive: Home")
        robot.execute_primitive(pt_home)

        # (2) Move robot joints to target positions
        # ------------------------------------------------------------------------------------------
        # Required parameters:
        #     target: final joint positions, unit: degrees
        #         {arm joint positions}, {external axis joint positions, optional}
        # Optional parameters:
        #     waypoints: waypoints to pass before reaching the target
        #         (same format as above, but can be more than one)
        #     vel: TCP linear velocity, unit: m/s

        pt_movej = Motion.MoveJ(
            params={
                Motion.MoveJ.InputParams.Basic.Target: JointPositionType(
                    30, -45, 0, 90, 0, 40, 30, -50, 30
                ),
                Motion.MoveJ.InputParams.Basic.Waypoints: [
                    JointPositionType(10, -30, 10, 30, 10, 15, 10, -15, 10),
                    JointPositionType(20, -60, -10, 60, -10, 30, 20, -30, 20),
                ],
            },
            conditions={Motion.MoveJ.State.ReachedTarget: 1},
        )

        # Send command to robot and wait for reached target
        logger.info("Executing primitive: MoveJ")
        robot.execute_primitive(pt_movej, interval=1, timeout=30)

        # (3) Move robot TCP to a target pose in world (base) frame
        # ------------------------------------------------------------------------------------------
        # Required parameters:
        #     target: final TCP pose, unit: m and degrees
        #         {pos_x, pos_y, pos_z}, {rot_x, rot_y, rot_z}, {ref_frame, ref_point}
        # Optional parameters:
        #     waypoints: waypoints to pass before reaching the target
        #         (same format as above, but can be more than one)
        #     vel: TCP linear velocity, unit: m/s
        # NOTE: The rotations use Euler ZYX convention, rot_x means Euler ZYX angle around X axis

        pt_movel_world_frame = Motion.MoveL(
            params={
                Motion.MoveL.InputParams.Basic.Target: CoordinateType(
                    0.65, -0.3, 0.2, 180, 0, 180, WorldFrameType()
                ),
                Motion.MoveL.InputParams.Basic.Waypoints: [
                    CoordinateType(0.45, 0.1, 0.2, 180, 0, 180, WorldFrameType()),
                    CoordinateType(0.45, -0.3, 0.2, 180, 0, 180, WorldFrameType()),
                ],
                Motion.MoveL.InputParams.Basic.Vel: 0.6,
                Motion.MoveL.InputParams.Basic.ZoneRadius: "Z50",
            },
            conditions={Motion.MoveL.State.ReachedTarget: 1},
        )

        # Send command to robot and wait for reached target
        logger.info("Executing primitive: MoveL in world (base) frame")
        robot.execute_primitive(pt_movel_world_frame, interval=1, timeout=30)

        # (4) Another MoveL that uses TCP frame
        # ------------------------------------------------------------------------------------------
        # In this example the reference frame is changed from WORLD::WORLD_ORIGIN to TRAJ::START,
        # which represents the current TCP frame

        pt_movel_tcp_frame = Motion.MoveL(
            params={
                Motion.MoveL.InputParams.Basic.Target: CoordinateType(
                    0.0, 0.0, 0.0, 30, 30, 30, TrajFrameType(TrajFrameValueEnum.Start)
                ),
                Motion.MoveL.InputParams.Basic.Vel: 0.2,
            },
            conditions={Motion.MoveL.State.ReachedTarget: 1},
        )

        # Send command to robot and wait for reached target
        logger.info("Executing primitive: MoveL in tcp frame")
        robot.execute_primitive(pt_movel_tcp_frame, interval=1, timeout=30)

        # All done, stop robot and put into IDLE mode
        robot.stop()

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
