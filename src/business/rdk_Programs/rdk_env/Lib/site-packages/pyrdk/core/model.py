from typing import List

from flexivrdk import flexivrdk

from pyrdk.robot import Robot
from pyrdk.utils.robotics_util import RoboticsUtil


class Model:
    def __init__(self, robot: Robot, gravity_vector=(0, 0, -9.81)):
        assert robot is not None, "Robot is not initialized"
        self._robot = robot
        self._model = flexivrdk.Model(self._robot._robot, gravity_vector)
        self.link_names = self._model.link_names()

    def update(self, positions=None, velocities=None):
        """
        Update the configuration (posture) of the locally-stored robot model so that the locally computed functions
        return results based on the updated configuration.
        :param positions: Joint positions. Unit: [deg]
        :param velocities: Joint velocities. Unit: [deg/s]
        """
        if positions is None:
            positions = self._robot.joint_link_positions
        if velocities is None:
            velocities = self._robot.joint_motor_velocities
        p = [RoboticsUtil.deg_to_rad(p) for p in positions]
        v = [RoboticsUtil.deg_to_rad(v) for v in velocities]
        self._model.Update(p, v)

    def reload(self):
        """
        Reload (refresh) parameters of the robot model stored locally in this class
        using the latest data synced from the connected robot. Tool model is also synced
        """
        self._model.Reload()

    def sync_URDF(self, path):
        """
        Sync the actual kinematic parameters of the connected robot into the template URDF
        :param path: Path to the template URDF file that can be generated in flexiv_description.
        """
        self._model.SyncURDF(path)

    def reachable(
        self, pose: List[float], seed_position: List[float], free_orientation: bool
    ):
        """
        Check if a Cartesian pose is reachable. If yes, also return an IK solution of the corresponding joint positions.
        :param pose: Cartesian pose to be checked.
        :param seed_position: Joint positions to be used as the seed for solving IK.
        :param free_orientation: Only constrain position and allow orientation to move freely.
        :return: [is_reachable, IK_solution]
        """
        p = pose[:3] + RoboticsUtil.euler_to_quat(pose[3:])
        seed_jp = [RoboticsUtil.deg_to_rad(jp) for jp in seed_position]
        result = self._model.reachable(p, seed_jp, free_orientation)
        ik = [RoboticsUtil.rad_to_deg(p) for p in result[1]]
        return [result[0], ik]

    @property
    def coriolis_matrix(self):
        """Compute the Coriolis/centripetal matrix in generalized coordinates"""
        self.update()
        return self._model.C()

    @property
    def coriolis_vector(self):
        """Compute the Coriolis force vector in generalized coordinates"""
        self.update()
        return self._model.c()

    @property
    def gravity_vector(self):
        """Compute the gravity force vector in generalized coordinates, i.e. joint space"""
        self.update()
        return self._model.g()

    @property
    def mass_matrix(self):
        """Compute the mass matrix in generalized coordinates, i.e. joint space"""
        self.update()
        return self._model.M()

    @property
    def configuration_score(self):
        """
        Score of the robot's current configuration (posture), calculated from the manipulability measurements.
        :return: A pair of {translation_score, orientation_score}.
                 The quality of configuration based on score is mapped as:
                 poor = [0, 20), medium = [20, 40), good = [40, 100].
        """
        return self._model.configuration_score()

    def jacobian(self, link_name: str):
        """Compute the Jacobian matrix at the specified frame w.r.t. world frame"""
        self.update()
        return self._model.J(link_name)

    def jacobian_dot(self, link_name: str):
        """Compute the time derivative of Jacobian matrix at the specified frame w.r.t. world frame"""
        self.update()
        return self._model.dJ(link_name)

    def transformation_matrix(self, link_name: str):
        """Compute the transformation matrix of the specified frame w.r.t. world frame"""
        self.update()
        return self._model.T(link_name)

    def sync_kinematics_yaml(self, path: str):
        """
        Sync the actual kinematic parameters of the connected robot into the template YAML file.
        :param path: path to the template YAML file located at [flexiv_description/config/.../default_kinematics.yaml].
                     This template YAML file will be updated when the sync is finished.
        """
        return self._model.SyncKinematicsYAML(path)