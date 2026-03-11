import time

import spdlog

from pyrdk.core.tool import Tool
from pyrdk.robot import Robot


def main():
    # Program Setup
    # ==============================================================================================

    # Define alias
    logger = spdlog.ConsoleLogger("Example")

    # Print description
    logger.info(
        ">>> Tutorial description <<<\nThis tutorial shows how to online update and interact with "
        "the robot tools. All changes made to the robot tool system will take effect immediately "
        "without needing to reboot. However, the robot must be put into IDLE mode when making "
        "these changes.\n"
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

        # Update Robot Tool
        # ==========================================================================================

        # Get and print a list of already configured tools currently in the robot's tools pool
        logger.info("All configured tools:")
        tool_list = robot.tool_list
        for i in range(len(tool_list)):
            print(f"[{i}] {tool_list[i]}")
        print()

        # Get and print the current active tool
        logger.info(f"Current active tool: [{robot.current_tool_name}]")

        # Set name and parameters for a new tool
        new_tool = Tool(name="ExampleTool1", robot=robot)
        new_tool.mass = 0.9
        new_tool.CoM = [0.0, 0.0, 0.057]
        new_tool.inertia = [2.768e-03, 3.149e-03, 5.64e-04, 0.0, 0.0, 0.0]
        new_tool.tcp_location = [0.0, -0.207, 0.09, 180, 0, 180]

        # If there's already a tool with the same name in the robot's tools pool, then remove it
        # first, because duplicate tool names are not allowed
        if new_tool.exists():
            logger.warn(
                f"Tool with the same name [{new_tool.name}] already exists, removing it now"
            )
            # Switch to other tool or no tool (Flange) before removing the current tool
            robot.switch_tool("Flange")
            new_tool.remove()

        # Add the new tool
        logger.info(f"Adding new tool [{new_tool.name}] to the robot")
        new_tool.add()

        # Get and print the tools list again, the new tool should appear at the end
        logger.info("All configured tools:")
        tool_list = robot.tool_list
        for i in range(len(tool_list)):
            print(f"[{i}] {tool_list[i]}")
        print()

        # Switch to the newly added tool, i.e. set it as the active tool
        logger.info(f"Switching to tool [{new_tool.name}]")
        robot.switch_tool(new_tool.name)

        # Get and print the current active tool again, should be the new tool
        logger.info(f"Current active tool: [{robot.current_tool_name}]")

        # Switch to other tool or no tool (Flange) before removing the current tool
        robot.switch_tool("Flange")

        # Clean up by removing the new tool
        time.sleep(2)
        logger.info(f"Removing tool [{new_tool.name}]")
        new_tool.remove()

        logger.info("Program finished")

    except Exception as e:
        logger.error(str(e))


if __name__ == "__main__":
    main()
