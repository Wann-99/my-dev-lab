import spdlog

from pyrdk.core.plan import Plan
from pyrdk.robot import Robot


def print_plan_info(robot):
    """Print plan info while the current plan is running"""
    print(f"assigned_plan_name: {robot.assigned_plan_name}")
    print(f"pt_name: {robot.current_pt_name}")
    print(f"node_name: {robot.current_node_name}")
    print(f"node_path: {robot.current_node_path}")
    print(f"node_path_time_period: {robot.current_node_path_time_period}")
    print(f"node_path_number: {robot.current_node_path_number}")
    print(f"velocity_scale: {robot.velocity_scale}")
    print(f"waiting_for_step: {robot.waiting_for_step}")
    print("", flush=True)


def monitor_plan(robot):
    """Monitors the execution plan of a robot"""
    if robot.is_fault():
        raise Exception("Fault occurred on the connected robot, exiting ...")
    print_plan_info(robot)


def main():
    # Program Setup
    # ==============================================================================================

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial executes a plan by specifying its name. "
        "A plan is a pre-written script to execute a series of robot "
        "primitives with pre-defined transition conditions between 2 adjacent primitives. Users "
        "can use Flexiv Elements to compose their own plan and assign to the robot, which "
        "will appear in the plan list.\n"
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

        # Execute plan by name
        # ==========================================================================================
        plan = Plan(str(input("Enter plan name to execute:\n")))
        robot.execute_plan(
            plan=plan, interval=1, timeout=60, callback=monitor_plan, robot=robot
        )

    except Exception as e:
        # Print exception error message
        logger.error(str(e))


if __name__ == "__main__":
    main()
