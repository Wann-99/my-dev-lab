import spdlog

from pyrdk.core.primitives.basic_force_control import BasicForceControl
from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial zeros the robot's force and torque sensors, "
        "which is a recommended (but not mandatory) step before any operations that require "
        "accurate force/torque measurement.\n"
    )

    try:
        # RDK Initialization
        # ==========================================================================================
        # Instantiate robot interface
        robot = Robot(ip="127.0.0.1")

        # Enable the robot and wait for the robot to become operational
        logger.info("Enabling robot ...")
        robot.enable()

        # Zero Sensors
        # ==========================================================================================
        # Get and print the current TCP force/moment readings
        logger.info(
            f"TCP force and moment reading in world frame BEFORE sensor zeroing: {robot.ext_wrench_in_world} N-Nm"
        )

        # Run the "ZeroFTSensor" primitive to automatically zero force and torque sensors
        # WARNING: during the process, the robot must not contact anything, otherwise the result
        # will be inaccurate and affect following operations
        logger.warn(
            "Zeroing force/torque sensors, make sure nothing is in contact with the robot"
        )
        pt_zeroftsensor = BasicForceControl.ZeroFTSensor(
            conditions={BasicForceControl.ZeroFTSensor.State.Terminated: 1}
        )
        robot.execute_primitive(pt_zeroftsensor)
        logger.info("Sensor zeroing complete")

        # Get and print the current TCP force/moment readings
        logger.info(
            f"TCP force and moment reading in world frame AFTER sensor zeroing: {robot.ext_wrench_in_world} N-Nm"
        )

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
