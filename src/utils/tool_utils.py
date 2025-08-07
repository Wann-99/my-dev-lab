import sys
sys.path.insert(0, '/home/sunseed/Music/lib')

import flexivrdk
import logging

logger = logging.getLogger(__name__)



def get_current_tool_parameters(robot, mode=None):
    """
    获取当前工具的质量和TCP位置

    参数:
        robot (flexivrdk.Robot): 机器人对象

    返回:
        dict: 包含当前工具的质量 (mass) 和 TCP 位置 (tcp_location)
    """
    result = {}
    try:
        # 确保机器人处于空闲模式
        robot.SwitchMode(mode.IDLE)

        # 获取当前活动工具
        tool = flexivrdk.Tool(robot)
        logger.info(f"current_tool: [{tool.name()}]")
        current_tool_name = tool.name()

        # 如果机器人当前未配置工具，返回默认值
        if not current_tool_name or current_tool_name == "Flange":
            result["mass"] = None
            result["tcp_location"] = None
            return result
        # tool.Switch(current_tool_name)
        # 获取当前工具参数
        current_tool_params = tool.params()
        # 提取并返回所需参数
        result["mass"] = current_tool_params.mass
        result["tcp_location"] = current_tool_params.tcp_location
    except Exception as e:
        logger.error(f"Error getting tool parameters: {str(e)}")
        result["mass"] = None
        result["tcp_location"] = None

    return result