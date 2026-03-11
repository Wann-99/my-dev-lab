from typing import List

import flexivrdk

from pyrdk.log import logger
from pyrdk.robot import Robot
from pyrdk.utils.robotics_util import RoboticsUtil


class Safety:

    def __init__(self, robot: Robot, password: str = "flexiv"):
        self.robot = robot
        self._safety = flexivrdk.Safety(self.robot._robot, password)

    def _parse_limits(self, limits):
        """
        parse SafetyLimit struct
        :param limits:
        :return:
        """
        return {
            "position_limits": {
                "min": [RoboticsUtil.rad_to_deg(item) for item in limits.q_min],
                "max": [RoboticsUtil.rad_to_deg(item) for item in limits.q_max],
            },
            "normal_speed_limits": [RoboticsUtil.rad_to_deg(item) for item in limits.dq_max_normal],
            "reduced_speed_limits": [RoboticsUtil.rad_to_deg(item) for item in limits.dq_max_reduced],
        }

    @property
    def default_joint_limits(self):
        """
        Current values of the safety limits of the connected robot.
        :return:
        """
        limits = self._safety.default_limits()
        return self._parse_limits(limits)

    @property
    def current_joint_limits(self):
        """
        Current reading from all safety input ports.
        :return:
        """
        limits = self._safety.current_limits()
        return self._parse_limits(limits)

    def set_joint_pos_limits(
        self, min_positions: List[float], max_positions: List[float]
    ):
        """
        Set joint position limits.
        :param min_positions: Unit: [deg]. Valid range: [default_min_joint_positions, default_max_joint_positions].
        :param max_positions: Unit: [deg]. Valid range: [default_min_joint_positions, default_max_joint_positions].
        :return:
        """
        assert (
            len(min_positions) == len(max_positions) == 7
        ), "len of min/max_positions should be 7"
        for i in range(len(min_positions)):
            default_min = self.default_joint_limits["position_limits"]["min"]
            default_max = self.default_joint_limits["position_limits"]["max"]
            assert (
                default_min[i] <= min_positions[i] <= default_max[i]
            ), f"min position[{i}] = {min_positions[i]} out of range [{default_min[i]}, {default_max[i]}] "
            assert (
                default_min[i] <= max_positions[i] <= default_max[i]
            ), f"max position[{i}] = {max_positions[i]} out of range [{default_min[i]}, {default_max[i]}] "
            assert (
                min_positions[i] < max_positions[i]
            ), f"min position[{i}] ({min_positions[i]}) cannot be greater than max position[{i}] ({max_positions[i]})"
        min_p = [RoboticsUtil.deg_to_rad(p) for p in min_positions]
        max_p = [RoboticsUtil.deg_to_rad(p) for p in max_positions]
        self.robot.switch_mode_to_idle()
        self._safety.SetJointPositionLimits(min_p, max_p)
        logger.warn(
            "A reboot is required for the updated joint position limits to take effect."
        )

    def set_joint_vel_normal_limits(self, max_vels: List[float]):
        """
        Set joint velocity normal limits.
        :param max_vels: Unit: [deg/s].  Valid range: [50.002, joint_velocity_normal_limits].
        :return:
        """
        assert len(max_vels) == 7, "len of max_vels should be 7"
        for i in range(len(max_vels)):
            assert (
                50.002 <= max_vels[i] <= self.default_joint_limits["normal_speed_limits"][i]
            ), f"max_vel[{i}] = {max_vels[i]} out of range [50.002, {self.default_joint_limits['normal_speed_limits'][i]}"
        self.robot.switch_mode_to_idle()
        self._safety.SetJointVelocityNormalLimits(
            [RoboticsUtil.deg_to_rad(v) for v in max_vels]
        )
        logger.warn(
            "A reboot is required for the updated joint vel normal limits to take effect."
        )

    def set_joint_vel_reduced_limits(self, max_vels: List[float]):
        """
        Set joint velocity reduced limits
        :param max_vels: Unit: [deg/s].  Valid range: [50.002, joint_velocity_normal_limits].
        :return:
        """
        assert len(max_vels) == 7, "len of max_vels should be 7"
        for i in range(len(max_vels)):
            assert (
                50.002 <= max_vels[i] <= self.default_joint_limits["normal_speed_limits"][i]
            ), f"max_vel[{i}] = {max_vels[i]} out of range [50.002, {self.default_joint_limits['normal_speed_limits'][i]}"
        self.robot.switch_mode_to_idle()
        self._safety.SetJointVelocityReducedLimits(
            [RoboticsUtil.deg_to_rad(v) for v in max_vels]
        )
        logger.warn(
            "A reboot is required for the updated joint vel reduce limits to take effect."
        )

    @property
    def inputs(self):
        """
        Current reading from all safety input ports.
        :return:
        """
        return self._safety.safety_inputs()

    def set_joint_output_torque_regulator(self, limiting_factor: float = 1.3, error_threshold: int = 50):
        """
        Change settings of the regulator on the joint output torques of the manipulator and external axes.
        The regulator will limit the joints' total output torques so that the measured torques are less likely to exceed safety limits under large payload or fast/abrupt motions.
        :param limiting_factor: Factor to limit the total output torques
        :param error_threshold: If the unregulated output torque of any joint exceeds the configured regulator limit for more than [error_threshold] cycles consecutively,
                                the robot will trigger a minor fault and stop.
        """
        self.robot.switch_mode_to_idle()
        self._safety.SetJointOutputTorqueRegulator(
            limiting_factor=limiting_factor,
            error_threshold=error_threshold)