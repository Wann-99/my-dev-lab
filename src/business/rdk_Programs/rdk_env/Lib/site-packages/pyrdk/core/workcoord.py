from flexivrdk import flexivrdk

from pyrdk.utils.robotics_util import RoboticsUtil


class WorkCoord:
    def __init__(self, name, robot):
        assert robot is not None, "Robot is not initialized"
        self.name = name
        self._robot = robot
        self._workcoord = flexivrdk.WorkCoord(self._robot._robot)
        self.pose = None
        if self.exists():
            self.load_params_from_robot()

    def load_params_from_robot(self):
        if not self.exists():
            raise RuntimeError(f"WorkCoord {self.name} does not exist")
        pose = self._workcoord.pose(self.name)
        self.pose = [round(x, 5) for x in pose[:3]] + [
            round(x, 2) for x in RoboticsUtil.quat_to_euler_zyx(pose[3:])
        ]

    def exists(self) -> bool:
        """
        Whether the specified work coordinate already exists.
        :return:
        """
        return self._workcoord.exist(self.name)

    def add(self):
        """
        Add a new work coordinate with user-specified parameter.
        """
        self._robot.switch_mode_to_idle()
        pose = self.pose[:3] + RoboticsUtil.euler_to_quat(self.pose[3:])
        self._workcoord.Add(self.name, pose)

    def update(self):
        """
        Update the parameters of an existing workcoord.
        """
        self._robot.switch_mode_to_idle()
        pose = self.pose[:3] + RoboticsUtil.euler_to_quat(self.pose[3:])
        self._workcoord.Update(self.name, pose)

    def remove(self):
        """
        Remove an existing work coordinate.
        """
        self._robot.switch_mode_to_idle()
        self._workcoord.Remove(self.name)
