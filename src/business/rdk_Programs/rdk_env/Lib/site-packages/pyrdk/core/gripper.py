import time

from flexivrdk import flexivrdk

from pyrdk.enums import GripperNameEnum
from pyrdk.robot import Robot


class Gripper:

    def __init__(self, name: GripperNameEnum, robot: Robot):
        assert robot is not None, "Robot is not initialized"
        self._robot = robot
        self._gripper = flexivrdk.Gripper(self._robot._robot)

        self.name = name.value
        self.min_width = None
        self.max_width = None
        self.min_force = None
        self.max_force = None
        self.min_vel = None
        self.max_vel = None

        self._force = None
        self._width = None
        self._moving = None

    def _init_gripper_info(self):
        params = self._gripper.params()
        self.min_width = round(params.min_width, 5)
        self.max_width = round(params.max_width, 5)
        self.min_force = round(params.min_force, 5)
        self.max_force = round(params.max_force, 5)
        self.min_vel = round(params.min_vel, 5)
        self.max_vel = round(params.max_vel, 5)

    def get_gripper_states(self):
        states = self._gripper.states()
        self._force = states.force
        self._width = states.width
        self._moving = states.is_moving

    @property
    def width(self) -> float:
        """
        Measured finger opening width [m]
        """
        return round(self._width, 5)

    @property
    def force(self) -> float:
        """
        Measured finger force. Positive: opening force, negative: closing force.
        Reads 0 if the enabled gripper has no force sensing capability [N]
        """
        return round(self._force, 5)

    def is_moving(self) -> bool:
        """
        Whether the gripper fingers are moving
        """
        return self._moving

    def enable(self):
        """
        Enable the specified gripper as a robot device and get gripper info
        """
        self._gripper.Enable(self.name)
        self._init_gripper_info()
        self.get_gripper_states()

    def disable(self):
        """
        Disable the currently enabled gripper
        """
        self._gripper.Disable()

    def init(self, init: bool = True, init_delay: float = 10):
        """
        :param init: Manually trigger the initialization of the enabled gripper
        """
        if init:
            self._gripper.Init()
            time.sleep(init_delay)

    def move(
            self, width: float, velocity: float, force_limit: float, init: bool = False
    ):
        """
        Move the gripper fingers with position control.
        :param width: Target opening width;
                      Valid range: [GripperParams::min_width, GripperParams::max_width];
                      Unit: [m].
        :param velocity: Closing/opening velocity, cannot be 0;
                         Valid range: [GripperParams::min_vel, GripperParams::max_vel];
                         Unit: [m/s].
        :param force_limit: Maximum contact force during movement;
                            Valid range: [GripperParams::min_force, GripperParams::max_force];
                            Unit: [N].
        :param init: Manually trigger the initialization of the enabled gripper
        """

        self.init(init=init)
        self._gripper.Move(width, velocity, force_limit)

    def stop(self):
        """
        Stop the gripper and hold its current finger width
        """
        self._gripper.Stop()

    def grasp(self, force: float, init: bool = False):
        """
        Grasp with direct force control
        :param force: Positive: closing force, negative: opening force
                      Valid range: [gripper.min_force, gripper.max_force]. Unit: [N].
        :param init: Manually trigger the initialization of the enabled gripper
        :return:
        """
        self.init(init=init)
        self._gripper.Grasp(force)
