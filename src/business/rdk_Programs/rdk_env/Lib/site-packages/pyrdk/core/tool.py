from flexivrdk import flexivrdk

from pyrdk.utils.robotics_util import RoboticsUtil


class Tool:
    def __init__(self, name, robot):
        assert robot is not None, "Robot is not initialized"

        self.name = name
        self._robot = robot
        self._tool = flexivrdk.Tool(self._robot._robot)
        self.mass = None
        self.CoM = None  # Center of mass in robot flange frame: [x,y,z]. Unit: [m]
        self.inertia = None  # [Ixx,Iyy,Izz,Ixy,Ixz,Iyz]
        self.tcp_location = None  # [x,y,z,qw,qx,qy,qz]
        if self.exists():
            self.load_params_from_robot()

    def load_params_from_robot(self):
        if not self.exists():
            raise RuntimeError(f"Tool {self.name} does not exist")
        tool_params = self._tool.params(self.name)
        self.mass = round(tool_params.mass, 3)
        self.CoM = [round(com, 5) for com in tool_params.CoM]
        self.inertia = tool_params.inertia
        self.tcp_location = [round(x, 5) for x in tool_params.tcp_location[:3]] + [
            round(x, 2)
            for x in RoboticsUtil.quat_to_euler_zyx(tool_params.tcp_location[3:])
        ]

    def exists(self) -> bool:
        """
        check whether tool exists
        :return:
        """
        return self._tool.exist(self.name)

    def add(self):
        """
        Add a new tool with user-specified parameters.
        """
        self._robot.switch_mode_to_idle()
        tool_params = flexivrdk.ToolParams()
        tool_params.mass = self.mass
        tool_params.CoM = self.CoM
        tool_params.inertia = self.inertia
        tool_params.tcp_location = self.tcp_location[:3] + RoboticsUtil.euler_to_quat(
            self.tcp_location[3:]
        )
        self._tool.Add(self.name, tool_params)

    def update(self):
        """
        Update the parameters of an existing tool.
        """
        if not self.exists():
            raise RuntimeError(f"Tool {self.name} does not exist")
        self._robot.switch_mode_to_idle()
        tool_params = flexivrdk.ToolParams()
        tool_params.mass = self.mass
        tool_params.CoM = self.CoM
        tool_params.inertia = self.inertia
        tool_params.tcp_location = self.tcp_location[:3] + RoboticsUtil.euler_to_quat(
            self.tcp_location[3:]
        )
        self._tool.Update(self.name, tool_params)

    def remove(self):
        """
        Remove an existing tool
        """
        if not self.exists():
            raise RuntimeError(f"Tool {self.name} does not exist")
        self._robot.switch_mode_to_idle()
        if self.name == "Flange":
            raise ValueError("Cannot remove the 'Flange' tool")
        self._tool.Remove(self.name)
