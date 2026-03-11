import spdlog

from pyrdk.core.global_var import GlobalVariable
from pyrdk.robot import Robot
from pyrdk.types import CoordinateType, WorkFrameType, WorldFrameType


def main():
    # Program Setup
    # ==============================================================================================

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial shows how to get and set global variables.\n"
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

        # Get existing global variables
        # =========================================================================================
        global_vars = robot.get_global_variables()
        if not global_vars:
            logger.warn("No global variables available")
            return 1
        else:
            logger.info("Existing global variables and their original values:")
            for var in global_vars:
                print(f"{var.name}: {var.value}")

        # Set global variables
        # =========================================================================================
        # WARNING: These specified global variables need to be created first using Flexiv Elements
        logger.info("Setting new values to existing global variables")
        gv_test_bool = GlobalVariable(name="test_bool", value=True)
        gv_test_int = GlobalVariable(name="test_int", value=100)
        gv_test_double = GlobalVariable(name="test_double", value=100.123)
        gv_test_string = GlobalVariable(name="test_string", value="Flexiv")
        gv_test_int_vec = GlobalVariable(name="test_int_vec", value=[1, 2, 3])
        gv_test_double_vec = GlobalVariable(name="test_double_vec", value=[1.1, 2.2, 3.3])
        gv_test_string_vec = GlobalVariable(name="test_string_vec", value=["Go", "Flexiv", "Go!"])
        gv_test_pose = GlobalVariable(name="test_pose", value=[0.1, -0.2, 0.3, -90, -45, 120])
        gv_test_coord = GlobalVariable(name="test_coord", value=CoordinateType(
            0.1, -0.2, 0.3, -90, -45, 120, WorldFrameType(),
            1, 2, 3, 4, 5, 6, 7,
            10, 20, ))
        gv_test_coord_array = GlobalVariable(
            name="test_coord_array",
            value=[
                CoordinateType(1, 2, 3, 4, 5, 6, WorkFrameType("WorkCoord0")),
                CoordinateType(10, 20, 30, 40, 50, 60, WorldFrameType(),
                               1, 2, 3, 4, 5, 6, 7,
                               10, 20),
                CoordinateType(3, 2, 1, 180, 0, 180, WorldFrameType()),
            ],
        )
        robot.set_global_variable(
            [gv_test_bool, gv_test_int, gv_test_double, gv_test_string,
             gv_test_int_vec, gv_test_double_vec, gv_test_string_vec,
             gv_test_pose, gv_test_coord,
             gv_test_coord_array, ])

        # Get updated global variables
        # =========================================================================================
        global_vars = robot.get_global_variables()
        if not global_vars:
            logger.warn("No global variables available")
            return 1
        else:
            logger.info("Updated global variables:")
            for var in global_vars:
                print(f"{var.name}: {var.value}")

        logger.info("Program finished")

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
