from typing import Dict
import pynng

from pyrdk.settings import ROBOT_NANOMSG_BLOCK_ON_DAIL
from pyrdk.settings import ROBOT_NANOMSG_RECONNECT_TIME_MAX
from pyrdk.settings import ROBOT_NANOMSG_RECONNECT_TIME_MIN
from pyrdk.settings import ROBOT_NANOMSG_RECV_TIMEOUT
from pyrdk.utils.robotics_util import RoboticsUtil
from pyrdk.utils.time_util import TimeUtil
from pyrdk.log import logger
from pyrdk.protos.pb2 import RobotState_pb2


class RizonNanomsgClient:
    def __init__(self, robot_ip: str, robot_nanomsg_port: int):
        self.ip = robot_ip
        self.port = robot_nanomsg_port
        self.socket = None

    def connect(self):
        self.socket = pynng.Sub0(
            dial=f"tcp://{self.ip}:{self.port}",
            reconnect_time_min=ROBOT_NANOMSG_RECONNECT_TIME_MIN,
            reconnect_time_max=ROBOT_NANOMSG_RECONNECT_TIME_MAX,
            recv_timeout=ROBOT_NANOMSG_RECV_TIMEOUT,
            block_on_dial=ROBOT_NANOMSG_BLOCK_ON_DAIL,
        )
        self.socket.subscribe("")

    def is_connected(self) -> bool:
        try:
            msg = self.socket.recv_msg()
            if len(msg.bytes) == 0:
                return False
            return True
        except pynng.exceptions.Timeout:
            return False
        except Exception as e:
            logger.error(f"error when checking if robot is connected: {e}")
            return False

    def disconnect(self):
        if self.socket:
            self.socket.close()

    def _read(self) -> RobotState_pb2.ProtoRobotState:
        msg = self.socket.recv_msg()
        data = RobotState_pb2.ProtoRobotState()
        data.ParseFromString(msg.bytes)
        return data

    async def _async_read(self):
        msg = await self.socket.arecv_msg()
        data = RobotState_pb2.ProtoRobotState()
        data.ParseFromString(msg.bytes)
        return data

    def read_robot_state(self) -> Dict:
        raw_data = self._read()
        results = {}
        # joints
        ## joint basic
        results["joint_basic"] = []
        for i in range(1, 8):
            results["joint_basic"].append(
                {
                    "name": f"A{i}",
                    "position": self.read_joint_positions(raw_data)["positions"][i - 1],
                    "velocity": self.read_joint_velocities(raw_data)["velocities"][
                        i - 1
                        ],
                    "acceleration": self.read_joint_accelerations(raw_data)[
                        "accelerations"
                    ][i - 1],
                }
            )
        ## joint motor
        results["joint_motor"] = []
        for i in range(1, 8):
            results["joint_motor"].append(
                {
                    "name": f"A{i}",
                    "temperature": self.read_joint_temperatures(raw_data)[
                        "temperatures"
                    ][i - 1],
                }
            )
        ## joint mcu
        results["joint_mcu"] = []
        for i in range(1, 8):
            results["joint_mcu"].append(
                {
                    "name": f"A{i}",
                    "temperature": self.read_joint_mcu_temperature(raw_data)[
                        "temperatures"
                    ][i - 1],
                }
            )
        ## joint led
        results["joint_led"] = []
        for i in range(1, 8):
            results["joint_led"].append(
                {
                    "name": f"A{i}",
                    "led": round(
                        1.0
                        - float(self.read_joint_leds(raw_data)["leds"][i - 1]) / 100,
                        2,
                    ),
                }
            )
        results["system_info"] = self.read_system_info(raw_data)
        ## external axis
        axis_number = len(raw_data.joint_data.ext_axis_pos.data)
        results["axis_basic"] = []
        for i in range(1, axis_number + 1):
            results["axis_basic"].append(
                {
                    "name": f"X{i}",
                    "position": self.read_ext_axis_positions(raw_data)["positions"][
                        i - 1
                        ],
                    "velocity": self.read_ext_axis_velocities(raw_data)["velocities"][
                        i - 1
                        ],
                    "torque": self.read_ext_axis_torques(raw_data)["torques"][i - 1],
                }
            )
        results["tcp_basic"] = self.read_cartesian()
        return results

    def read_joint_cartesian(self) -> Dict:
        raw_data = self._read()
        results = {}
        # cartesian
        ## cartesian position
        cartesian_positions = self.read_cartesian_positions(raw_data)
        results.update({"tcp_position": cartesian_positions["positions"]})
        cartesian_velocities = self.read_cartesian_velocities(raw_data)
        results.update({"tcp_velocity": cartesian_velocities["velocities"]})
        cartesian_wrenches = {"tcp_wrench": ["0.00" for _ in range(6)]}
        results.update(cartesian_wrenches)
        # joints
        ## joint basic
        results["joint_basic"] = []
        for i in range(1, 8):
            results["joint_basic"].append(
                {
                    "name": f"A{i}",
                    "position": self.read_joint_positions(raw_data)["positions"][i - 1],
                    "torque": self.read_joint_torques(raw_data)["torques"][i - 1],
                    "velocity": self.read_joint_velocities(raw_data)["velocities"][
                        i - 1
                        ],
                    "acceleration": self.read_joint_accelerations(raw_data)[
                        "accelerations"
                    ][i - 1],
                }
            )
        ## joint motor
        results["joint_motor"] = []
        for i in range(1, 8):
            results["joint_motor"].append(
                {
                    "name": f"A{i}",
                    "positions": self.read_joint_motor_positions(raw_data)["positions"][
                        i - 1
                        ],
                    "current": self.read_joint_currents(raw_data)["currents"][i - 1],
                    "temperature": self.read_joint_temperatures(raw_data)[
                        "temperatures"
                    ][i - 1],
                }
            )
        ## joint mcu
        results["joint_mcu"] = []
        for i in range(1, 8):
            results["joint_mcu"].append(
                {
                    "name": f"A{i}",
                    "temperature": self.read_joint_mcu_temperature(raw_data)[
                        "temperatures"
                    ][i - 1],
                }
            )
        results["system_info"] = self.read_system_info(raw_data)
        return results

    def read_joints_torque_stiff(self):
        raw_data = self._read()
        results = {"joints_torque_stiff": {}}
        for i in range(1, 8):
            results["joints_torque_stiff"][f"A{i}"] = {
                "motor_pos": self.read_joint_motor_positions(raw_data)["positions"][
                    i - 1
                    ],
                "link_pos": self.read_joint_positions(raw_data)["positions"][i - 1],
                "joint_torque": self.read_joint_torques(raw_data)["torques"][i - 1],
            }
        return results

    def read_arm_servo(self, raw_data=None):
        def is_robot_fault(cur_system_state: int) -> bool:
            if cur_system_state in [13, 14, 15, 16, 17, 18]:
                return True
            return False

        def get_servo(safety_board_state: int) -> str:
            if safety_board_state in [9, 10, 12, 136]:
                return "on"
            else:
                return "off"

        if not raw_data:
            raw_data = self._read()
        fault_state = is_robot_fault(raw_data.system_info.cur_system_state)
        servo_state = get_servo(raw_data.safety_board_info.state)
        if fault_state:
            state = "fault"
        else:
            state = servo_state

        return {
            "servo": state,
        }

    def read_cartesian(self) -> Dict:
        positions = self.read_cartesian_positions()
        velocities = self.read_cartesian_velocities()
        # wrenches = self.read_cartesian_wrenches()
        result = {}
        result.update(positions)
        result.update(velocities)
        result.update({"wrenches": ["0.00" for _ in range(6)]})
        return result

    async def async_read_cartesian(self) -> Dict:
        positions = await self.async_read_cartesian_positions()
        velocities = await self.async_read_cartesian_velocities()
        # wrenches = await self.async_read_cartesian_wrenches()
        return {"positions": positions, "velocities": velocities, "wrenches": []}

    def read_cartesian_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        euler_angles = RoboticsUtil.quat_to_euler_zyx(
            [
                raw_data.cart_data.tcp_pose.quat.x,
                raw_data.cart_data.tcp_pose.quat.y,
                raw_data.cart_data.tcp_pose.quat.z,
                raw_data.cart_data.tcp_pose.quat.w,
            ]
        )
        return {
            "positions": [
                round(raw_data.cart_data.tcp_pose.pos.x * 1000, 2),
                round(raw_data.cart_data.tcp_pose.pos.y * 1000, 2),
                round(raw_data.cart_data.tcp_pose.pos.z * 1000, 2),
                round(euler_angles[0], 2),
                round(euler_angles[1], 2),
                round(euler_angles[2], 2),
            ]
        }

    async def async_read_cartesian_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        euler_angles = RoboticsUtil.quat_to_euler_zyx(
            [
                raw_data.cart_data.tcp_pose.quat.x,
                raw_data.cart_data.tcp_pose.quat.y,
                raw_data.cart_data.tcp_pose.quat.z,
                raw_data.cart_data.tcp_pose.quat.w,
            ]
        )
        return {
            "positions": [
                raw_data.cart_data.tcp_pose.pos.x * 1000,
                raw_data.cart_data.tcp_pose.pos.y * 1000,
                raw_data.cart_data.tcp_pose.pos.z * 1000,
                euler_angles[0],
                euler_angles[1],
                euler_angles[2],
            ]
        }

    def read_cartesian_velocities(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        velocities = []
        for idx, item in enumerate(raw_data.cart_data.tcp_vel.data):
            if idx > 2:
                velocities.append(
                    str(
                        round(
                            RoboticsUtil.rad_to_deg(
                                raw_data.cart_data.tcp_vel.data[idx]
                            ),
                            2,
                        )
                        + 0.0
                    )
                )
            else:
                velocities.append(str(round(item, 2) + 0.0))
        return {"velocities": velocities}

    async def async_read_cartesian_velocities(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        velocities = []
        for idx, item in enumerate(raw_data.cart_data.tcp_vel.data):
            if idx > 2:
                velocities.append(
                    RoboticsUtil.rad_to_deg(raw_data.cart_data.tcp_vel.data[idx])
                )
            else:
                velocities.append(item)
        return {"velocities": velocities}

    def read_cartesian_wrenches(self):
        raise NotImplementedError

    def read_cartesian_accelerations(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {"accelerations": raw_data.cart_data.tcp_acc.data}

    def read_target_cartesian_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        poses = [
            raw_data.cart_data.target_pose.quat.x,
            raw_data.cart_data.target_pose.quat.y,
            raw_data.cart_data.target_pose.quat.z,
            raw_data.cart_data.target_pose.quat.w,
        ]
        positions = RoboticsUtil.quat_to_euler_zyx(poses)
        return {
            "positions": [
                raw_data.cart_data.tcp_pose.pos.x,
                raw_data.cart_data.tcp_pose.pos.y,
                raw_data.cart_data.tcp_pose.pos.z,
                *positions,
            ]
        }

    def read_joints(self) -> Dict:
        results = {}
        index = [f"A{i}" for i in range(1, 8)]
        results.update({"index": index})
        positions = self.read_joint_positions()
        results.update(positions)
        torques = self.read_joint_torques()
        results.update(torques)
        velocities = self.read_joint_velocities()
        results.update(velocities)
        currents = self.read_joint_currents()
        results.update(currents)
        temperatures = self.read_joint_temperatures()
        results.update(temperatures)
        return results

    async def async_read_joints(self) -> Dict:
        results = {}
        positions = await self.async_read_joint_positions()
        results.update(positions)
        torques = await self.async_read_joint_torques()
        results.update(torques)
        velocities = await self.async_read_joint_velocities()
        results.update(velocities)
        return results

    def read_joint_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "positions": [
                round(RoboticsUtil.rad_to_deg(item), 2) + 0.0
                for item in raw_data.joint_data.jnt_pos.data
            ]
        }

    async def async_read_joint_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        return {
            "positions": [
                round(RoboticsUtil.rad_to_deg(item), 2) + 0.0
                for item in raw_data.joint_data.jnt_pos.data
            ]
        }

    def read_joint_torques(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "torques": [
                round(data, 2) + 0.0 for data in raw_data.joint_data.jnt_torque.data
            ]
        }

    async def async_read_joint_torques(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        return {
            "torques": [
                round(data, 2) + 0.0 for data in raw_data.joint_data.jnt_torque.data
            ]
        }

    def read_joint_velocities(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "velocities": [
                round(RoboticsUtil.rad_to_deg(item), 2) + 0.0
                for item in raw_data.joint_data.jnt_vel.data
            ]
        }

    async def async_read_joint_velocities(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        return {
            "velocities": [
                round(RoboticsUtil.rad_to_deg(item), 2)
                for item in raw_data.joint_data.jnt_vel.data
            ]
        }

    def read_joint_temperatures(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "temperatures": [
                str(round(data, 2) + 0.0)
                for data in raw_data.joint_data.jnt_temperature.data
            ]
        }

    def read_joint_accelerations(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "accelerations": [
                str(round(data, 2) + 0.0) for data in raw_data.joint_data.jnt_acc.data
            ]
        }

    def read_joint_ext_torques(self) -> Dict:
        data = self._read()
        return {
            "ext_torques": [
                str(round(data, 2) + 0.0)
                for data in data.joint_data.jnt_ext_torque.data
            ]
        }

    def read_joint_currents(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "currents": [
                round(data, 2) + 0.0 for data in raw_data.joint_data.jnt_current.data
            ]
        }

    def read_joint_mcu_temperature(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "temperatures": [
                round(data, 2) + 0.0
                for data in raw_data.joint_data.mcu_temperature.data
            ]
        }

    def read_joint_motor_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "positions": [
                round(RoboticsUtil.rad_to_deg(item), 2) + 0.0
                for item in raw_data.joint_data.motor_pos.data
            ]
        }

    def read_joint_leds(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {"leds": [item for item in raw_data.cmd_info.cmd_jnt_led.data]}

    async def async_read_joint_leds(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        return {"leds": [item for item in raw_data.cmd_info.cmd_jnt_led.data]}

    async def async_read_joint_motor_positions(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = await self._async_read()
        return {
            "positions": [
                round(RoboticsUtil.rad_to_deg(item), 2) + 0.0
                for item in raw_data.joint_data.motor_pos.data
            ]
        }

    def read_ext_axis_positions(self, raw_data=None) -> Dict:
        """
        如果外部轴是pan-tilt，需要将弧度转为角度; 如果线性轴输出的单位是米。
        :param raw_data:
        :return:,
        """
        if not raw_data:
            raw_data = self._read()
        return {
            "positions": [
                str(round(item, 2) + 0.0)
                for item in raw_data.joint_data.ext_axis_pos.data
            ]
        }

    def read_ext_axis_torques(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "torques": [
                str(round(item, 2) + 0.0)
                for item in raw_data.joint_data.ext_axis_torque.data
            ]
        }

    def read_ext_axis_velocities(self, raw_data=None) -> Dict:
        if not raw_data:
            raw_data = self._read()
        return {
            "velocities": [
                str(round(item, 2) + 0.0)
                for item in raw_data.joint_data.ext_axis_vel.data
            ]
        }

    def read_ext_axis(self) -> Dict:
        data = self._read()
        return {
            "positions": [
                str(round(item, 2) + 0.0) for item in data.joint_data.ext_axis_pos.data
            ],
            "torques": [
                str(round(item, 2) + 0.0)
                for item in data.joint_data.ext_axis_torque.data
            ],
            "velocities": [
                str(round(item, 2) + 0.0) for item in data.joint_data.ext_axis_vel.data
            ],
        }

    def read_mbar_info(self) -> Dict:
        data = self._read()
        return {
            "is_connected": data.mbar_info.is_connected,
            "is_emergency": data.mbar_info.is_emergency,
            "is_freedrive": data.mbar_info.is_free_drive,
            "is_teach_minus": data.mbar_info.is_teach_minus,
            "is_teach_plus": data.mbar_info.is_teach_plus,
            "is_confirmed": data.mbar_info.is_confirmed,
            "is_enabled": data.mbar_info.is_enabled,
            "mode": data.mbar_info.mode,
        }

    def read_reboot_info(self) -> Dict:
        data = self._read()
        return {
            "need_reboot": data.mbar_info.need_reboot,
        }

    def read_robot_fault_info(self) -> Dict:
        data = self._read()
        return {
            "robot_fault": data.safety_board_info.robot_fault,
        }

    def read_system_fault_info(self) -> Dict:
        data = self._read()
        return {
            "system_fault": data.safety_board_info.system_fault,
        }

    def read_safety_board_info(self) -> Dict:
        data = self._read()
        return {
            "mode": data.safety_board_info.mode,
            "robot_fault": data.safety_board_info.robot_fault,
            "state": data.safety_board_info.state,
            "system_fault": data.safety_board_info.system_fault,
        }

    def read_system_info(self, raw_data=None) -> Dict:
        def get_robot_mode(cur_system_state: int) -> str:
            if cur_system_state in [2, 6, 9, 11, 13, 16]:
                return "manual"
            elif cur_system_state in [3, 7, 12, 10, 14, 17]:
                return "auto"
            elif cur_system_state in [4, 5, 8, 15, 18]:
                return "auto_remote"
            else:
                raise Exception(f"unknown robot mode value: {cur_system_state}")

        def get_robot_state(cur_system_state: int) -> str:
            if cur_system_state in [5, 6, 7, 8, 9, 10]:
                return "working"
            elif cur_system_state in [2, 3, 4]:
                return "stopped"
            elif cur_system_state in [13, 14, 15]:
                return "fault"
            elif cur_system_state in [16, 17, 18]:
                return "recovery"
            elif cur_system_state in [11, 12]:
                return "freedrive"
            else:
                raise Exception(f"unknown robot state value: {cur_system_state}")

        def get_estop(is_emergency_raw: str) -> str:
            if not is_emergency_raw:
                return "pressed"
            else:
                return "released"

        def get_servo(safety_board_state: int) -> str:
            if safety_board_state in [9, 10, 12, 136]:
                return "on"
            else:
                return "off"

        def get_step_mode(cur_step_mode: int) -> bool:
            return True if cur_step_mode == 1 else False

        def get_waypoint_mode(cur_step_mode: int) -> bool:
            return True if cur_step_mode == 2 else False

        def get_learning_mode(cur_step_mode: int) -> bool:
            return True if cur_step_mode == 8 else False

        if not raw_data:
            raw_data = self._read()
        return {
            "assigned_plan_name": raw_data.system_info.assigned_plan_name,
            "assigned_plan_velocity_scale": raw_data.system_info.assigned_plan_velocity_scale,
            "breakpoint_mode": raw_data.system_info.breakpoint_mode,
            "step_mode": get_step_mode(raw_data.system_info.step_mode),
            "waypoint_mode": get_waypoint_mode(raw_data.system_info.step_mode),
            "learning_mode": get_learning_mode(raw_data.system_info.step_mode),
            "cur_node_path": raw_data.system_info.cur_node_path,
            "cur_node_path_num": raw_data.system_info.cur_node_path_num,
            "cur_node_path_time_period": raw_data.system_info.cur_node_path_time_period,
            "cur_pt_name": raw_data.system_info.cur_pt_name,
            "cur_system_state": raw_data.system_info.cur_system_state,
            "cur_waypoint_index": raw_data.system_info.current_waypoint_index,
            "robot_mode": get_robot_mode(raw_data.system_info.cur_system_state),
            "robot_state": get_robot_state(raw_data.system_info.cur_system_state),
            "estop": get_estop(raw_data.mbar_info.is_emergency_raw),
            "servo": get_servo(raw_data.safety_board_info.state),
        }

    def read_timestamp(self) -> Dict:
        data = self._read()
        return {
            "timestamp": TimeUtil.timestamp_to_microseconds(data.time_since_epoch)
        }

    def read_bub_digital_input(self) -> Dict:
        data = self._read()
        return {"bub_digital_input": data.gpio_in}

    def read_bub_digital_output(self) -> Dict:
        data = self._read()
        return {"bub_digital_output": data.gpio_out}

    def read_gpio_state(self) -> Dict:
        data = self._read()
        return {"gpio_state": data.gpio_state}
