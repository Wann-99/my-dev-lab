import math
import os.path
import time
from typing import List

import flexivrdk

from pyrdk.core.global_var import GlobalVariable
from pyrdk.core.plan import Plan
from pyrdk.core.primitives import Primitive
from pyrdk.enums import DeviceNameEnum
from pyrdk.exceptions import (
    GlobalVariableSetException,
    PlanNotFoundException,
    RDKNotCompatibleException,
    RobotEnableException,
    RobotEstopNotReleasedException,
    RobotFaultNotClearedException,
    RobotInRecoveryException,
    RobotModeException,
    RobotNotOperationalException,
    RobotSerialNumberException,
)
from pyrdk.log import logger
from pyrdk.utils.robotics_util import RoboticsUtil


class Robot:

    def __init__(self, ip: str, version_check: bool = True):
        """

        :param ip: robot ip
        :param version_check: check robot version and rdk version
        """
        self.ip = ip
        self.version_check = version_check
        # default safety password
        self._safety_pwd = "flexiv"
        self._robot = None
        self._arm_serial_number = None
        self._cb_serial_number = None
        self._rca_version = None
        self._robot_mode = None
        self._robot_estop = None
        self._robot_servo = None
        self.gripper_name = None
        self.tool_name = None
        self.init_robot()

    def init_robot_info(self):
        from pyrdk.contrib.rizon_nanomsg_client import RizonNanomsgClient
        from pyrdk.settings import ROBOT_NANOMSG_PORT

        nanomsg_client = RizonNanomsgClient(
            robot_ip=self.ip, robot_nanomsg_port=ROBOT_NANOMSG_PORT
        )
        nanomsg_client.connect()
        robot_info = nanomsg_client.read_system_info()
        nanomsg_client.disconnect()
        self._robot_mode = robot_info.get("robot_mode", "")
        self._robot_estop = robot_info.get("estop", "")
        self._robot_servo = robot_info.get("servo", "")
        if self._robot_estop != "released":
            raise RobotEstopNotReleasedException()
        if self._robot_mode != "auto_remote":
            raise RobotModeException()

    def init_robot_versions(self):
        from pyrdk.contrib.rizon_grpc_client import RizonGrpcClient
        from pyrdk.settings import MAPPING_RCA, ROBOT_GRPC_PORT

        grpc_client = RizonGrpcClient(robot_ip=self.ip, robot_grpc_port=ROBOT_GRPC_PORT)
        robot_versions = grpc_client.get_versions()
        grpc_client.close()
        self._arm_serial_number = robot_versions.get("arm_business_serial_number", "")
        self._cb_serial_number = robot_versions.get("cb_business_serial_number", "")
        self._rca_version = robot_versions.get("rca", "")
        if self.version_check and not self._rca_version.startswith(MAPPING_RCA):
            raise RDKNotCompatibleException()
        if not self._arm_serial_number:
            raise RobotSerialNumberException()

    def init_robot(self):
        self.init_robot_info()
        self.init_robot_versions()
        try:
            self._robot = flexivrdk.Robot(self._arm_serial_number)
        except Exception as ex:
            logger.error(ex)

    @property
    def arm_serial_number(self) -> str:
        """
        arm's business serial number
        :return:
        """
        return self._arm_serial_number

    @property
    def cb_serial_number(self) -> str:
        """
        control box's business serial number
        :return:
        """
        return self._cb_serial_number

    @property
    def mode(self) -> str:
        """
        robot mode
        :return: auto, manual, auto_remote
        """
        return self._robot_mode

    @property
    def estop(self) -> str:
        """
        robot estop
        :return: released, pressed
        """
        return self._robot_estop

    @property
    def servo(self) -> str:
        """
        robot servo on
        :return: on, off
        """
        return self._robot_servo

    @property
    def model_name(self) -> str:
        """
        Robot model name
        :return: Rizon4, Rizon10, Moonlight, etc.
        """
        return self._robot.info().model_name

    @property
    def license_type(self) -> str:
        """
        Type of license
        :return:
        """
        return self._robot.info().license_type

    @property
    def DoF(self):
        """
        Joint-space degrees of freedom of the full system including the robot manipulator and any external axes
        :return: int
        """
        return self._robot.info().DoF

    @property
    def DoF_e(self):
        """
        Joint-space degrees of freedom of the external axes
        :return: int
        """
        return self._robot.info().DoF_e

    @property
    def DoF_m(self):
        """
        Joint-space degrees of freedom of the robot manipulator
        :return: int
        """
        return self._robot.info().DoF_m

    @property
    def joint_nominal_stiffness(self):
        """
        Nominal motion stiffness of the joint impedance control modes
        Unit: [Nm/deg].
        :return:
        """
        k_q_nom = [
            round(stiffness / RoboticsUtil.rad_to_deg(1.0, 15), 4)
            for stiffness in self._robot.info().K_q_nom
        ]
        return k_q_nom

    @property
    def cartesian_nominal_stiffness(self):
        """
        Nominal motion stiffness of the Cartesian motion-force control modes: Consists of linear stiffness and angular stiffness
        Unit: [N/m]:[Nm/deg].
        :return:
        """
        k_x_nom_info = self._robot.info().K_x_nom
        linear = [round(i, 4) for i in k_x_nom_info[:3]]
        angular = [
            round(stiffness / RoboticsUtil.rad_to_deg(1.0, 15), 4)
            for stiffness in k_x_nom_info[3:]
        ]
        return linear + angular

    @property
    def joint_position_lower_limits(self):
        """
        Lower software limits of joint positions
        Unit: [deg].
        :return: list
        """
        return [RoboticsUtil.rad_to_deg(i) for i in self._robot.info().q_min]

    @property
    def joint_position_upper_limits(self):
        """
        Upper software limits of joint positions
        Unit: [deg].
        :return: list
        """
        return [RoboticsUtil.rad_to_deg(i) for i in self._robot.info().q_max]

    @property
    def joint_velocity_upper_limits(self):
        """
        Upper software limits of joint velocities
        Unit: [deg/s].
        :return: list
        """
        return [RoboticsUtil.rad_to_deg(i) for i in self._robot.info().dq_max]

    @property
    def joint_torque_upper_limits(self):
        """
        Upper software limits of joint torques
        Unit: [Nm].
        :return: list
        """
        return self._robot.info().tau_max

    @property
    def has_ft_sensor(self):
        """
        Whether the robot has a force-torque (FT) sensor installed
        :return: bool
        """
        return self._robot.info().has_FT_sensor

    @property
    def joint_link_positions(self) -> List[float]:
        """
        关节连杆位置
        Unit: deg
        :return: list
        """
        states_q = self._robot.states().q
        joint_positions = [RoboticsUtil.rad_to_deg(i) for i in states_q]
        return joint_positions

    @property
    def joint_link_velocities(self) -> List[float]:
        """
        关节角速度
        Unit: deg / s
        :return: list
        """
        states_dq = self._robot.states().dq
        joint_velocities = [RoboticsUtil.rad_to_deg(i) for i in states_dq]
        return joint_velocities

    @property
    def joint_motor_positions(self) -> List[float]:
        """
        关节角度
        Unit: deg
        :return: list
        """
        states_theta = self._robot.states().theta
        joint_positions = [RoboticsUtil.rad_to_deg(i) for i in states_theta]
        return joint_positions

    @property
    def joint_motor_velocities(self) -> List[float]:
        """
        关节角速度
        Unit: deg / s
        :return: list
        """
        states_dtheta = self._robot.states().dtheta
        joint_velocities = [RoboticsUtil.rad_to_deg(i) for i in states_dtheta]
        return joint_velocities

    @property
    def tcp_pose(self) -> List[float]:
        """
        tcp位姿
        Unit: m : deg
        :return: [x, y, z, rz, ry, rx]
        """
        states_tcp_pose = self._robot.states().tcp_pose
        tcp_pose = [float(i) for i in states_tcp_pose]
        tcp_pose = [round(i, 5) for i in tcp_pose[:3]] + [
            round(float(i), 4) for i in RoboticsUtil.quat_to_euler_zyx(tcp_pose[3:])
        ]
        return tcp_pose

    @property
    def flange_pose(self) -> List[float]:
        """
        法兰位姿
        Unit: m : deg
        :return: [x, y, z, rz, ry, rx]
        """
        states_flange_pose = self._robot.states().flange_pose
        flange_pose = [float(i) for i in states_flange_pose]
        flange_pose = [round(i, 5) for i in flange_pose[:3]] + [
            round(float(i), 4) for i in RoboticsUtil.quat_to_euler_zyx(flange_pose[3:])
        ]
        return flange_pose

    @property
    def joint_torques(self) -> List[float]:
        """
        关节力矩
        Unit: [Nm]
        :return: list
        """
        states_tau = self._robot.states().tau
        joint_torques = [float(i) for i in states_tau]
        joint_torques = [round(i, 4) for i in joint_torques]
        return joint_torques

    @property
    def desired_joint_torque(self) -> List[float]:
        """
        Desired joint torques of the full system
        Compensation of nonlinear dynamics (gravity, centrifugal, and Coriolis) is excluded.
        If a joint has no torque control capability, the corresponding value will be 0.
        Unit: [Nm].
        :return: list
        """
        tau_des_list = self._robot.states().tau_des
        return [round(float(tau), 4) for tau in tau_des_list]

    @property
    def derivative_of_measured_joint_torques(self) -> List[float]:
        """
        Numerical derivative of measured joint torques of the full system
        Unit: [Nm/s]
        :return: list
        """
        tau_dot_list = self._robot.states().tau_dot
        return [round(float(tau), 4) for tau in tau_dot_list]

    @property
    def external_joint_torque(self) -> List[float]:
        """
        Estimated external joint torques of the full system
        Unit:  [Nm].
        :return: list
        """
        ext_tau_list = self._robot.states().tau_ext
        return [round(float(tau), 4) for tau in ext_tau_list]

    @property
    def estimated_interaction_joint_torques(self) -> List[float]:
        """
        Estimated interaction joint torques of the full system. Produced by any interaction forces at the TCP.
        Unit: [Nm]
        :return: list
        """
        tau_interact_list = self._robot.states().tau_interact
        return [round(float(tau), 4) for tau in tau_interact_list]

    @property
    def ft_sensor_raw_reading(self) -> List[float]:
        """
        Force-torque (FT) sensor raw reading in flange frame
        The value is 0 if no FT sensor is installed.
        Unit:  [Nm].
        :return: list
        """
        ft_sensor_raw_list = self._robot.states().ft_sensor_raw
        return [round(float(tau), 4) for tau in ft_sensor_raw_list]

    @property
    def ext_wrench_in_tcp(self) -> List[float]:
        """
        Estimated external wrench w.r.t. TCP frame
        Unit:  [Nm].
        :return: list
        """
        ext_wrench_in_tcp_list = self._robot.states().ext_wrench_in_tcp
        return [round(float(tau), 4) for tau in ext_wrench_in_tcp_list]

    @property
    def ext_wrench_in_tcp_raw(self) -> List[float]:
        """
        Unfiltered version of ext_wrench_in_tcp. The data is more noisy but has no filter latency
        Unit:  [Nm].
        :return: list
        """
        ext_wrench_in_tcp_raw_list = self._robot.states().ext_wrench_in_tcp_raw
        return [round(float(tau), 4) for tau in ext_wrench_in_tcp_raw_list]

    @property
    def ext_wrench_in_world(self) -> List[float]:
        """
        Estimated external wrench w.r.t. world frame
        Unit:  [Nm].
        :return: list
        """
        ext_wrench_in_world_list = self._robot.states().ext_wrench_in_world
        return [round(float(tau), 4) for tau in ext_wrench_in_world_list]

    @property
    def ext_wrench_in_world_raw(self) -> List[float]:
        """
        Unfiltered version of ext_wrench_in_world. The data is more noisy but has no filter latency
        Unit:  [Nm].
        :return: list
        """
        ext_wrench_in_world_raw_list = self._robot.states().ext_wrench_in_world_raw
        return [round(float(tau), 4) for tau in ext_wrench_in_world_raw_list]

    @property
    def tcp_velocities(self) -> List[float]:
        """
        tcp 速度
        Unit: [m/s]:[deg/s].
        :return: [vx, vy, vz, wx, wy, wz]
        """
        states_tcp_vel = self._robot.states().tcp_vel  # [vx, vy, vz, wx, wy, wz]
        tcp_velocities = [round(float(i), 5) for i in states_tcp_vel[:3]] + [
            RoboticsUtil.rad_to_deg(float(i)) for i in states_tcp_vel[3:]
        ]
        return tcp_velocities

    @property
    def joint_temperatures(self):
        """
        关节温度
        Unit: [°C]
        :return: list
        """
        states_temperature = self._robot.states().temperature
        temperature = [round(i, 4) for i in states_temperature]
        return temperature

    @property
    def timestamp(self) -> tuple[int, int]:
        """
        timestamp 转为秒和纳秒
        :return: tuple(int, int)
        """
        seconds, nanoseconds = self._robot.states().timestamp
        return (seconds, nanoseconds)

    @property
    def assigned_plan_name(self) -> str:
        """
        Assigned plan name
        :return: str
        """
        return self._robot.plan_info().assigned_plan_name

    @property
    def current_node_name(self) -> str:
        """
        Current node name
        :return: str
        """
        return self._robot.plan_info().node_name

    @property
    def current_node_path(self) -> str:
        """
        Current node path
        :return: str
        """
        return self._robot.plan_info().node_path

    @property
    def current_node_path_number(self) -> str:
        """
        Current node path number
        :return: str
        """
        return self._robot.plan_info().node_path_number

    @property
    def current_node_path_time_period(self) -> str:
        """
        Current node path time period
        :return: str
        """
        return self._robot.plan_info().node_path_time_period

    @property
    def current_pt_name(self) -> str:
        """
        Current primitive name
        :return: str
        """
        return self._robot.plan_info().pt_name

    @property
    def velocity_scale(self) -> str:
        """
        Velocity scale
        :return: float
        """
        return self._robot.plan_info().velocity_scale

    @property
    def waiting_for_step(self) -> str:
        """
        Waiting for user signal to step the breakpoint
        :return: bool
        """
        return self._robot.plan_info().waiting_for_step

    @property
    def digital_inputs(self):
        """
        Current reading from all digital input ports, including 16 on the control box plus 2 inside the wrist connector.
        :return: list(bool)
        """
        return self._robot.digital_inputs()

    def is_stopped(self):
        """
        Whether the robot has come to a complete stop
        :return: bool
        """
        return self._robot.stopped()

    def is_operational(self) -> bool:
        """
        Whether the robot is ready to be operated
        Which requires the following conditions to be met: enabled, brakes fully released, in auto mode, no fault, and not in reduced state.
        :return: bool
        """
        return self._robot.operational()

    def is_busy(self) -> bool:
        """
        Whether the robot is busy
        :return: bool
        """
        return self._robot.busy()

    def is_fault(self) -> bool:
        """
        Whether the robot is in fault state
        :return: bool
        """
        return self._robot.fault()

    def is_recovery(self) -> bool:
        """
        Whether the robot is in recovery state
        :return: bool
        """
        return self._robot.recovery()

    def is_reduced(self) -> bool:
        """
        Whether the robot is in reduced state
        :return: bool
        """
        return self._robot.reduced()

    def is_enabling_button_pressed(self) -> bool:
        """
        Whether the enabling button is pressed
        :return: bool
        """
        return self._robot.enabling_button_pressed()

    @property
    def joint_impedance_stiffness(self):
        """
        Joint motion stiffness. Unit: [Nm/deg].
        Setting motion stiffness of a joint axis to 0 will make this axis free-floating.
        Valid range: [0, robot.joint_nominal_stiffness].
        """
        logger.warn("joint_impedance_stiffness is write-only and should not be read.")
        return None

    @joint_impedance_stiffness.setter
    def joint_impedance_stiffness(self, values: List[float]):
        """
        Set impedance properties of the robot's joint motion controller used in the joint impedance control modes.
        """
        joint_nominal_stiffness = self.joint_nominal_stiffness
        assert len(values) == len(
            joint_nominal_stiffness
        ), f"Expected {len(joint_nominal_stiffness)} values, got {len(values)}"
        for i in range(len(values)):
            stiffness = joint_nominal_stiffness[i]
            assert (
                0 <= values[i] <= stiffness
            ), f"joint_impedance_stiffness[{i}]={values[i]} out of valid range [0, {stiffness}]"
        self.switch_mode_to_joint_impedance_control()
        self._joint_impedance_stiffness = [
            round(s / RoboticsUtil.deg_to_rad(1.0), 2) if not math.isinf(s) else s
            for s in values
        ]
        damping = getattr(self, "_joint_impedance_damping_ratio", None)
        if damping is not None:
            self._robot.SetJointImpedance(self._joint_impedance_stiffness, damping)
        else:
            self._robot.SetJointImpedance(self._joint_impedance_stiffness)

    @property
    def joint_impedance_damping_ratio(self):
        """
        Joint motion damping ratio.
        If None, the default value 0.7 is used.
        Valid range: [0.3, 0.8].
        """
        logger.warn(
            "joint_impedance_damping_ratio is write-only and should not be read."
        )
        return None

    @joint_impedance_damping_ratio.setter
    def joint_impedance_damping_ratio(self, values: List[float] = None):
        """
        Set impedance properties of the robot's joint motion controller used in the joint impedance control modes.
        """
        if values is None:
            values = [0.7] * self.DoF
        assert len(values) == self.DoF, f"Expected {self.DoF} values, got {len(values)}"
        for i in range(len(values)):
            assert (
                0.3 <= values[i] <= 0.8
            ), f"joint_impedance_damping_ratio[{i}]={values[i]} out of valid range [0.3, 0.8]"
        self.switch_mode_to_joint_impedance_control()
        self._joint_impedance_damping_ratio = values
        stiffness = getattr(self, "_joint_impedance_stiffness", None)
        if stiffness is not None:
            self._robot.SetJointImpedance(
                stiffness, self._joint_impedance_damping_ratio
            )
        else:
            assert False, "joint_impedance_stiffness is not set."

    @property
    def joint_inertia_scale(self):
        """
        joint_inertia_scale: Inertia shaping scales, 1.0 means no shaping (nominal safe value).
        Valid range: [0.75, 1.0].
        """
        logger.warn("joint_inertia_scale is write-only and should not be read.")
        return None

    @joint_inertia_scale.setter
    def joint_inertia_scale(self, values: List[float]):
        """
        Set inertia shaping scales for the robot's joint motion controller used in the joint impedance control modes
        """
        assert len(values) == self.DoF, f"Expected {self.DoF} values, got {len(values)}"
        for i in range(len(values)):
            assert (
                0.75 <= values[i] <= 1.0
            ), f"{values[i]} out of valid range [0.75, 1.0]"
        self.switch_mode_to_joint_impedance_control()
        self._robot.SetJointInertiaScale(values)

    @property
    def cartesian_impedance_stiffness(self):
        """
        Cartesian motion stiffness. Unit: [Nm/deg].
        Setting motion stiffness of a motion-controlled Cartesian axis to 0 will make this axis free-floating
        If None, the joint impedance will not be updated.
        Valid range: [0, robot.cartesian_nominal_stiffness].
        """
        logger.warn(
            "cartesian_impedance_stiffness is write-only and should not be read."
        )
        return None

    @cartesian_impedance_stiffness.setter
    def cartesian_impedance_stiffness(self, values: List[float]):
        """
        Set impedance properties of the robot's Cartesian motion controller
        used in the Cartesian motion-force control modes
        """
        cartesian_nominal_stiffness = self.cartesian_nominal_stiffness
        assert len(values) == len(
            cartesian_nominal_stiffness
        ), f"Expected {len(cartesian_nominal_stiffness)} values, got {len(values)}"
        for i in range(len(values)):
            stiffness = cartesian_nominal_stiffness[i]
            assert (
                0 <= values[i] <= stiffness
            ), f"cartesian_impedance_stiffness[{i}]={values[i]} out of valid range [0, {stiffness}]"
        self.switch_mode_to_cartesian_motion_force_control()
        self._cartesian_impedance_stiffness = [
            float(linear) for linear in values[:3]
        ] + [round(angular / RoboticsUtil.deg_to_rad(1.0), 2) for angular in values[3:]]
        damping = getattr(self, "_cartesian_impedance_damping_ratio", None)
        if damping is not None:
            self._robot.SetCartesianImpedance(
                self._cartesian_impedance_stiffness, damping
            )
        else:
            self._robot.SetCartesianImpedance(self._cartesian_impedance_stiffness)

    @property
    def cartesian_impedance_damping_ratio(self):
        """
        Cartesian motion damping ratio
        If None, the default value 0.7 is used.
        Valid range: [0.3, 0.8].
        """
        logger.warn(
            "cartesian_impedance_damping_ratio is write-only and should not be read."
        )
        return None

    @cartesian_impedance_damping_ratio.setter
    def cartesian_impedance_damping_ratio(self, values: List[float] = None):
        """
        Set impedance properties of the robot's Cartesian motion controller
        used in the Cartesian motion-force control modes
        """
        if values is None:
            values = [0.7] * 6
        assert len(values) == 6, f"Expected 6 values, got {len(values)}"
        for i in range(len(values)):
            assert (
                0.3 <= values[i] <= 0.8
            ), f"joint_impedance_damping_ratio[{i}]={values[i]} out of valid range [0.3, 0.8]"
        self.switch_mode_to_cartesian_motion_force_control()
        self._cartesian_impedance_damping_ratio = values
        stiffness = getattr(self, "_cartesian_impedance_stiffness", None)
        if stiffness is not None:
            self._robot.SetCartesianImpedance(
                stiffness, self._cartesian_impedance_damping_ratio
            )
        else:
            assert False, "cartesian_impedance_stiffness not set."

    @property
    def passive_force_control_is_enabled(self):
        """
        When enabled, an open-loop force controller will be used to feed forward the target wrench, i.e. passive force control.
        When disabled, a closed-loop force controller will be used to track the target wrench, i.e. active force control.
        """
        logger.warn(
            "passive_force_control_is_enable is write-only and should not be read."
        )
        return None

    @passive_force_control_is_enabled.setter
    def passive_force_control_is_enabled(self, is_enabled: bool):
        """
        Enable or disable passive force control for the Cartesian motion-force control modes.
        """
        self.switch_mode_to_idle()
        self._robot.SetPassiveForceControl(is_enabled)

    @property
    def force_control_axis_enabled_axes(self):
        """
        Flags to enable/disable force control for certain Cartesian axes in the force_control_frame.
        The axis order is [X,Y,Z,Rx,Ry,Rz].
        """
        logger.warn(
            "force_control_axis_enabled_axes is write-only and should not be read."
        )
        return None

    @force_control_axis_enabled_axes.setter
    def force_control_axis_enabled_axes(self, enabled_axes: List[bool]):
        """
        Set Cartesian axes to enable force control while in the Cartesian motion-force control modes.
        """
        assert len(enabled_axes) == 6, f"Expected 6 values, got {len(enabled_axes)}"
        self._force_control_axis_enabled_axes = enabled_axes
        max_linear_vel = getattr(
            self, "_force_control_axis_max_linear_vel", [1.0, 1.0, 1.0]
        )
        self.switch_mode_to_cartesian_motion_force_control()
        self._robot.SetForceControlAxis(enabled_axes, max_linear_vel)

    @property
    def force_control_axis_max_linear_vel(self):
        """
        For linear Cartesian axes that are enabled for force control,
        limit the moving velocity to these values as a protection mechanism in case of contact loss.
        The axis order is [X,Y,Z]. Valid range: [0.005, 2.0]. Unit: [m/s].
        """
        logger.warn(
            "force_control_axis_max_linear_vel is write-only and should not be read."
        )
        return None

    @force_control_axis_max_linear_vel.setter
    def force_control_axis_max_linear_vel(self, velocities: List[float]):
        """
        Set Cartesian axes to enable force control while in the Cartesian motion-force control modes.
        """
        assert len(velocities) == 3, f"Expected 3 values, got {len(velocities)}"
        for i in range(len(velocities)):
            assert (
                0.005 <= velocities[i] <= 2.0
            ), f"force_control_axis_max_linear_vel[{i}]={velocities[i]} out of valid range [0.005, 2.0]"
        self._force_control_axis_max_linear_vel = velocities
        enabled_axes = getattr(
            self,
            "_force_control_axis_enabled_axes",
            [False, False, False, False, False, False],
        )
        self.switch_mode_to_cartesian_motion_force_control()
        if any(enabled_axes):
            logger.warn(
                "The maximum linear velocity protection for force control axes is only effective "
                "under active force control (i.e. passive force control disabled)"
            )
            self._robot.SetForceControlAxis(enabled_axes, velocities)
        else:
            assert False, "There is no force control axis enabled. "

    @property
    def force_control_frame_root_coord_type(self):
        """
        Reference coordinate of force_control_frame_transformation_in_root
        """
        logger.warn(
            "force_control_frame_root_coord_type is write-only and should not be read."
        )
        return None

    @force_control_frame_root_coord_type.setter
    def force_control_frame_root_coord_type(self, is_world: bool):
        """
        Set reference frame for force control while in the Cartesian motion-force control modes.
        """
        if is_world:
            self._force_control_frame_root_coord_type = flexivrdk.CoordType.WORLD
        else:
            self._force_control_frame_root_coord_type = flexivrdk.CoordType.TCP
        self.switch_mode_to_cartesian_motion_force_control()
        t_in_root = getattr(
            self, "_force_control_frame_transformation_in_root", [0, 0, 0, 0, 0, 0]
        )
        self._robot.SetForceControlFrame(
            self._force_control_frame_root_coord_type,
            t_in_root[:3] + RoboticsUtil.euler_to_quat(t_in_root[3:]),
        )

    @property
    def force_control_frame_transformation_in_root(self):
        """
        Transformation from [root_coord] to the user-defined force control frame.  Unit: [m]:[deg].
        """
        logger.warn(
            "force_control_frame_transformation_in_root is write-only and should not be read."
        )
        return None

    @force_control_frame_transformation_in_root.setter
    def force_control_frame_transformation_in_root(self, values: List[float]):
        """
        Set reference frame for force control while in the Cartesian motion-force control modes.
        The force control frame is defined by specifying its transformation with regard to the root coordinate.
        """
        assert len(values) == 6, f"Expected 6 values, got {len(values)}"
        self._force_control_frame_transformation_in_root = values
        v = values[:3] + RoboticsUtil.euler_to_quat(values[3:])
        root_coord_type = getattr(
            self, "_force_control_frame_root_coord_type", flexivrdk.CoordType.WORLD
        )
        self.switch_mode_to_cartesian_motion_force_control()
        self._robot.SetForceControlFrame(root_coord_type, v)

    @property
    def max_contact_wrench(self):
        """
        Maximum contact wrench (force and moment). Unit: [N]:[Nm].
        """
        logger.warn("max_contact_wrench is write-only and should not be read.")
        return None

    @max_contact_wrench.setter
    def max_contact_wrench(self, values: List[float]):
        """
        Set maximum contact wrench for the motion control part of the Cartesian motion-force control modes.
        The controller will regulate its output to maintain contact wrench (force and moment) with the environment under the set values.
        """
        assert len(values) == 6, f"Expected 6 values, got {len(values)}"
        self.switch_mode_to_cartesian_motion_force_control()
        self._robot.SetMaxContactWrench(values)

    @property
    def null_space_posture(self):
        """
        Reference joint positions for the null-space posture control.
        Valid range: [robot.joint_position_lower_limits, robot.joint_position_upper_limits]. Unit: [deg].
        """
        logger.warn("null_space_posture is write-only and should not be read.")
        return None

    @null_space_posture.setter
    def null_space_posture(self, ref_positions: List[float]):
        """
        Set reference joint positions for the null-space posture control module used in the Cartesian motion-force control modes.
        """
        jp_min = self.joint_position_lower_limits
        jp_max = self.joint_position_upper_limits
        assert len(ref_positions) == len(
            jp_min
        ), f"Expected {len(jp_min)} values, got {len(ref_positions)}"
        for i in range(len(jp_min)):
            assert (
                jp_min[i] <= ref_positions[i] <= jp_max[i]
            ), f"null_space_posture[{i}]={ref_positions[i]} out of valid range [{jp_min[i]}, {jp_max[i]}]"
        self._robot.SetNullSpacePosture(
            [RoboticsUtil.deg_to_rad(p) for p in ref_positions]
        )

    def wait_for_operational(self, interval: int = 1, timeout: int = 30) -> bool:
        """
        wait until robot is operational, check every interval
        :param interval:
        :param timeout:
        :return: bool or exception
        """
        count = timeout / interval
        while not self.is_operational():
            if count > 0:
                count -= 1
                time.sleep(interval)
            else:
                raise RobotNotOperationalException()
        return True

    def clear_fault(self) -> bool:
        """
        clear robot fault
        :return: bool
        """
        if self.is_fault():
            if not self._robot.ClearFault():
                raise RobotFaultNotClearedException()
        return True

    def enable(self, timeout: int = 15) -> bool:
        """
        enable robot
        :param timeout: wait until robot is operational
        :return:
        """
        if self.servo != "on":
            try:
                self.clear_fault()
                self._robot.Enable()
                return self.wait_for_operational(timeout=timeout)
            except Exception as e:
                if self.is_recovery():
                    raise RobotInRecoveryException()
                else:
                    raise RobotEnableException() from e
        return True

    def stop(self):
        """
        stop the robot and transit its control mode to IDLE
        (This function blocks until the robot comes to a complete stop. )
        """
        self._robot.Stop()

    def run_auto_recovery(self):
        assert self._robot is not None, "Robot is not initialized"
        if self.is_recovery():
            self._robot.RunAutoRecovery()

    def get_plan_names(self) -> List[str]:
        """
        获取机器人中的plans
        :return: list of plan names
        """
        assert self._robot is not None, "Robot is not initialized"
        return self._robot.plan_list()

    def switch_mode_to_idle(self):
        """
        Switch the robot to IDLE mode.
        """
        assert self._robot is not None, "Robot is not initialized"
        if self._robot.mode() != flexivrdk.Mode.IDLE:
            self._robot.SwitchMode(flexivrdk.Mode.IDLE)

    def switch_mode_to_joint_position_control(self):
        """
        Switch the robot to non-real-time joint position control mode.
        """
        assert self._robot is not None, "Robot is not initialized"
        if self._robot.mode() != flexivrdk.Mode.NRT_JOINT_POSITION:
            self._robot.SwitchMode(flexivrdk.Mode.NRT_JOINT_POSITION)

    def switch_mode_to_joint_impedance_control(self):
        """
        Switch the robot to non-real-time joint impedance control mode.
        """
        assert self._robot is not None, "Robot is not initialized"
        if self._robot.mode() != flexivrdk.Mode.NRT_JOINT_IMPEDANCE:
            self._robot.SwitchMode(flexivrdk.Mode.NRT_JOINT_IMPEDANCE)

    def switch_mode_to_cartesian_motion_force_control(self):
        """
        Switch the robot to non-real-time Cartesian motion-force control mode.
        """
        assert self._robot is not None, "Robot is not initialized"
        if self._robot.mode() != flexivrdk.Mode.NRT_CARTESIAN_MOTION_FORCE:
            self._robot.SwitchMode(flexivrdk.Mode.NRT_CARTESIAN_MOTION_FORCE)

    def execute_primitive(
        self, primitive: Primitive, interval: int = 0.5, timeout: int = 3
    ) -> bool:
        """
        执行 primitive
        :param primitive:
        :param interval:
        :param timeout:
        :return:
        """
        if not hasattr(primitive, "params"):
            params = dict()
        else:
            params = dict()
            for k, v in primitive.params.items():
                if isinstance(v, list):
                    params[k.value] = [i.value if hasattr(i, "value") else i for i in v]
                else:
                    params[k.value] = v.value if hasattr(v, "value") else v
        self._robot.SwitchMode(flexivrdk.Mode.NRT_PRIMITIVE_EXECUTION)
        self._robot.ExecutePrimitive(primitive.PT_NAME, params)
        count = timeout / interval
        result = {}
        # wait for timeout or all conditions are satisfied
        while count > 0 and len(result.keys()) != len(primitive.conditions.keys()):
            for c_key, c_value in primitive.conditions.items():
                if not self._robot.primitive_states()[c_key.value] == c_value:
                    break
                result[c_key] = c_value
            count -= 1
            time.sleep(interval)
        if count == 0:
            logger.error(
                f"Primitive '{primitive}' failed to finish in given {timeout}s,"
                f" failed conditions: {primitive.conditions.keys() - result.keys()}"
            )
            return False
        return True

    def execute_plan(
        self,
        plan: Plan,
        interval: int = 1,
        timeout: int = 60,
        callback=None,
        *args,
        **kwargs,
    ) -> bool:
        """
        执行 plan
        :param plan: Plan
        :param interval: Sleep interval between status checks (seconds)
        :param timeout: Maximum execution time (seconds)
        :param callback: Optional callback to run in the monitoring loop
        :param args: Arguments for callback
        :return: True if plan executed successfully, False if timeout
        """
        if plan.name not in self.get_plan_names():
            raise PlanNotFoundException()
        self._robot.SwitchMode(flexivrdk.Mode.NRT_PLAN_EXECUTION)
        self._robot.ExecutePlan(plan.name)
        count = timeout // interval
        while count > 0:
            if callback:
                callback(*args, **kwargs)
            if not self.is_busy():
                return True
            count -= 1
            time.sleep(interval)
        logger.error(f"Plan '{plan.name}' failed to finish in given {timeout}s,")
        return False

    def send_joint_position(self, positions, velocities, max_vel, max_acc):
        """
        Discretely send joint position and velocity commands to the robot in joint position control mode.
        :param positions: Target joint positions.  Unit: [deg].
        :param velocities: Target joint velocities. Unit: [deg/s]
        :param max_vel: Maximum joint velocities for the planned trajectory. Unit: [deg/s]
        :param max_acc: Maximum joint accelerations for the planned trajectory: Unit: Unit: [deg/s^2].
        """
        self.switch_mode_to_joint_position_control()
        self._robot.SendJointPosition(
            [RoboticsUtil.deg_to_rad(p) for p in positions],
            [RoboticsUtil.deg_to_rad(v) for v in velocities],
            [RoboticsUtil.deg_to_rad(v) for v in max_vel],
            [RoboticsUtil.deg_to_rad(a) for a in max_acc],
        )

    def send_joint_position_with_impedance(
        self, positions, velocities, max_vel, max_acc
    ):
        """
        Discretely send joint position and velocity commands to the robot in joint impedance control mode.
        :param positions: Target joint positions.  Unit: [deg].
        :param velocities: Target joint velocities. Unit: [deg/s]
        :param max_vel: Maximum joint velocities for the planned trajectory. Unit: [deg/s]
        :param max_acc: Maximum joint accelerations for the planned trajectory: Unit: Unit: [deg/s^2].
        """
        self.switch_mode_to_joint_impedance_control()
        self._robot.SendJointPosition(
            [RoboticsUtil.deg_to_rad(p) for p in positions],
            [RoboticsUtil.deg_to_rad(v) for v in velocities],
            [RoboticsUtil.deg_to_rad(v) for v in max_vel],
            [RoboticsUtil.deg_to_rad(a) for a in max_acc],
        )

    def send_cartesian_motion_force(
        self,
        pose,
        wrench=None,
        velocity=None,
        max_linear_vel=0.5,
        max_angular_vel=57.2958,
        max_linear_acc=2.0,
        max_angular_acc=286.4789,
    ):
        """
        Discretely send Cartesian motion and/or force commands for the robot to track using its unified motion-force controller,
        which allows doing force control in zero or more Cartesian axes and motion control in the rest axes.
        :param pose: Target TCP pose in world frame.  Unit: [m]:[deg].
        :param wrench: Target TCP wrench (force and moment) in the force control reference frame. Unit: [N]:[Nm].
        :param velocity: Target TCP velocity (linear and angular) in world frame.
                         Providing properly calculated target velocity can improve the robot's overall tracking performance at the cost of reduced robustness.
                         Leaving this input 0 can maximize robustness at the cost of reduced tracking performance.
                         Unit: [m/s]:[deg/s].
        :param max_linear_vel: Maximum Cartesian linear velocity when moving to the target pose. Unit: [m/s].
        :param max_angular_vel: Maximum Cartesian angular velocity when moving to the target pose. Unit: [deg/s].
        :param max_linear_acc: Maximum Cartesian linear acceleration when moving to the target pose. Unit: [m/s^2].
        :param max_angular_acc: Maximum Cartesian angular acceleration when moving to the target pose. Unit: [deg/s^2].
        """
        self.switch_mode_to_cartesian_motion_force_control()
        if wrench is None:
            wrench = [0] * 6
        if velocity is None:
            velocity = [0] * 6
        p = pose[:3] + RoboticsUtil.euler_to_quat(pose[3:])
        v = velocity[:3] + [RoboticsUtil.rad_to_deg(v) for v in velocity[3:]]
        max_angvel = RoboticsUtil.deg_to_rad(max_angular_vel)
        max_angacc = RoboticsUtil.deg_to_rad(max_angular_acc)
        self._robot.SendCartesianMotionForce(
            p, wrench, v, max_linear_vel, max_angvel, max_linear_acc, max_angacc
        )

    @property
    def tool_list(self):
        """
        :return: Tool names as a string list.
        """
        tool = flexivrdk.Tool(self._robot)
        return tool.list()

    @property
    def current_tool_name(self) -> str:
        """
        :return: Name of the current tool.
        """
        tool = flexivrdk.Tool(self._robot)
        return tool.name()

    def switch_tool(self, tool_name: str):
        """
        Switch to an existing tool
        """
        assert self._robot is not None, "Robot is not initialized"
        if self._robot.mode() != flexivrdk.Mode.IDLE:
            self._robot.SwitchMode(flexivrdk.Mode.IDLE)
        _tool = flexivrdk.Tool(self._robot)
        _tool.Switch(tool_name)

    @property
    def workcoord_list(self) -> list:
        """
        A list of all configured work coordinates.
        """
        workcoord = flexivrdk.WorkCoord(self._robot)
        return workcoord.list()

    def get_global_variables(self) -> List[GlobalVariable]:
        """
        get robot's global variables
        :return:
        """
        assert self._robot is not None, "Robot is not initialized"
        g_vars = []
        for var_name, var_value in self._robot.global_variables().items():
            g_vars.append(
                GlobalVariable(
                    name=var_name,
                    value=var_value,
                )
            )
        return g_vars

    def set_global_variable(self, global_vars: List[GlobalVariable]):
        """
        Set values to global variables that already exist in the robot.
        """
        assert self._robot is not None, "Robot is not initialized"
        try:
            vars = dict()
            for var in global_vars:
                if isinstance(var.value, list):
                    vars[var.name] = [
                        v.value if hasattr(v, "value") else v for v in var.value
                    ]
                else:
                    vars[var.name] = (
                        var.value.value if hasattr(var.value, "value") else var.value
                    )
            self._robot.SetGlobalVariables(vars)
        except Exception as e:
            raise GlobalVariableSetException() from e

    @property
    def device_list(self) -> List[str]:
        """
        Get a list of device names.
        :return:
        """
        device = flexivrdk.Device(self._robot)
        d_lst = []
        for d in device.list():
            d_lst.append(DeviceNameEnum(d))
        return d_lst

    @property
    def safety_password(self):
        return self._safety_pwd

    @safety_password.setter
    def safety_password(self, new_password: str):
        self._safety_pwd = new_password

    @property
    def current_joint_limits(self) -> dict:
        """
        Get current safety joint limits.
        :return:
        """
        from pyrdk.core.safety import Safety

        safety = Safety(self, self._safety_pwd)
        return safety.current_joint_limits

    @property
    def safety_inputs(self) -> List[bool]:
        """
        Current reading from all safety input ports.
        :return:
        """
        from pyrdk.core.safety import Safety

        safety = Safety(self, self._safety_pwd)
        return safety.inputs

    @property
    def traj_files_list(self) -> List[str]:
        """
        A list of all trajectory files currently stored in the connected robot.
        :return:
        """
        io = flexivrdk.FileIO(self._robot)
        return io.traj_files_list()

    @property
    def projects_list(self):
        """
        A list of all user projects currently stored in the connected robot.
        :return:
        """
        io = flexivrdk.FileIO(self._robot)
        return io.projects_list()

    def upload_traj_file(self, file_fullname: str):
        """
        Upload a local trajectory file (.traj) to the robot.
        :param file_fullname:
        :return:
        """
        assert os.path.exists(file_fullname), "Trajectory file does not exist"
        assert os.path.getsize(file_fullname) <= 1024 * 1024, "Trajectory file size must be less than 1 MB"
        file_dir, file_name = os.path.split(file_fullname)
        io = flexivrdk.FileIO(self._robot)
        io.UploadTrajFile(file_dir, file_name)

    def download_traj_file_content(self, file_name: str):
        """
        Download a trajectory file (.traj) content from the robot.
        :param file_name:
        :return:
        """
        robot_trag_files = self.traj_files_list
        assert file_name in robot_trag_files, f"Trajectory file {file_name} does not exist in robot"
        io = flexivrdk.FileIO(self._robot)
        return io.DownloadTrajFile(file_name)

    def download_traj_file(self, file_name: str, save_dir: str):
        """
        Download a trajectory file (.traj) from the robot and save to the specified directory.
        :param file_name:
        :param save_dir:
        :return:
        """
        robot_trag_files = self.traj_files_list
        assert file_name in robot_trag_files, f"Trajectory file {file_name} does not exist in robot"
        os.makedirs(save_dir, exist_ok=True)
        io = flexivrdk.FileIO(self._robot)
        io.DownloadTrajFile(file_name, save_dir)

    def upload_project(self, project_dir: str):
        """
        Upload a local project to the robot.
        :param project_dir:
        :return:
        """
        from pathlib import Path
        assert os.path.exists(project_dir), f"Project directory {project_dir} does not exist"
        dir_path = Path(project_dir)
        has_plan = any(dir_path.glob("*.plan"))
        assert has_plan, f"Project directory {project_dir} does not contain any *.plan"
        has_proj = any(dir_path.glob("*.proj"))
        assert has_proj, f"Project directory {project_dir} does not contain any *.proj"
        io = flexivrdk.FileIO(self._robot)
        io.UploadProject(project_dir)

    def download_project(self, project_name: str, save_dir: str):
        """
        Download a project from the robot and save to the specified directory.
        :param project_name:
        :param save_dir:
        :return:
        """
        robot_prj_file_names = self.projects_list
        assert project_name in robot_prj_file_names, f"Project name {project_name} does not exist in robot"
        os.makedirs(save_dir, exist_ok=True)
        io = flexivrdk.FileIO(self._robot)
        io.DownloadProject(project_name, save_dir)

    def download_collision_mesh(self, save_dir: str):
        """
        Download all collision mesh files of the connected robot and save to the specified directory
        :param save_dir:
        :return:
        """
        os.makedirs(save_dir, exist_ok=True)
        io = flexivrdk.FileIO(self._robot)
        io.DownloadCollisionMesh(save_dir)

    def is_timeliness_failure_limit_reached(self) -> bool:
        """
        Whether the timeliness failure limit has been reached within a 1-second moving window.
        """
        return self._robot.reached_timeliness_failure_limit()
