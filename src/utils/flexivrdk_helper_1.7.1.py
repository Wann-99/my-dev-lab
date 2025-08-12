import numpy as np
from dataclasses import dataclass
from typing import List, Dict, Tuple, Optional, Any, Union, Callable


# 基础数据类型封装（替代C++中的自定义类型和Eigen）
@dataclass
class Pose:
    """位姿数据封装（位置+四元数）"""
    position: np.ndarray  # [x, y, z] in m
    quaternion: np.ndarray  # [w, x, y, z]

    def __init__(self, position: List[float] = None, quaternion: List[float] = None):
        self.position = np.array(position) if position else np.zeros(3)
        self.quaternion = np.array(quaternion) if quaternion else np.array([1, 0, 0, 0])


@dataclass
class ToolParams:
    """工具参数数据结构"""
    mass: float = 0.0  # kg
    com: np.ndarray = np.zeros(3)  # 质心 [x,y,z] in m
    inertia: np.ndarray = np.zeros(6)  # 惯性 [Ixx, Iyy, Izz, Ixy, Ixz, Iyz]
    tcp_location: np.ndarray = np.zeros(7)  # [x,y,z,qw,qx,qy,qz]


@dataclass
class Coord:
    """坐标数据结构封装"""
    position: np.ndarray = np.zeros(3)  # [x,y,z] in m
    orientation: np.ndarray = np.zeros(3)  # 欧拉角 [x,y,z] in degree
    ref_frame: List[str] = None
    ref_q_m: np.ndarray = np.zeros(7)  # 机器人关节参考位置
    ref_q_e: np.ndarray = np.zeros(3)  # 外部轴参考位置

    def __post_init__(self):
        if self.ref_frame is None:
            self.ref_frame = ["WORLD", "WORLD_ORIGIN"]


# 枚举类型定义
class Mode:
    """控制模式枚举"""
    UNKNOWN = 0
    IDLE = 1
    RT_JOINT_TORQUE = 2
    RT_JOINT_IMPEDANCE = 3
    NRT_JOINT_IMPEDANCE = 4
    RT_JOINT_POSITION = 5
    NRT_JOINT_POSITION = 6
    NRT_PLAN_EXECUTION = 7
    NRT_PRIMITIVE_EXECUTION = 8
    RT_CARTESIAN_MOTION_FORCE = 9
    NRT_CARTESIAN_MOTION_FORCE = 10
    NRT_SUPER_PRIMITIVE = 11

    @classmethod
    def to_str(cls, mode: int) -> str:
        mode_map = {
            cls.UNKNOWN: "UNKNOWN",
            cls.IDLE: "IDLE",
            cls.RT_JOINT_TORQUE: "RT_JOINT_TORQUE",
            cls.RT_JOINT_IMPEDANCE: "RT_JOINT_IMPEDANCE",
            cls.NRT_JOINT_IMPEDANCE: "NRT_JOINT_IMPEDANCE",
            cls.RT_JOINT_POSITION: "RT_JOINT_POSITION",
            cls.NRT_JOINT_POSITION: "NRT_JOINT_POSITION",
            cls.NRT_PLAN_EXECUTION: "NRT_PLAN_EXECUTION",
            cls.NRT_PRIMITIVE_EXECUTION: "NRT_PRIMITIVE_EXECUTION",
            cls.RT_CARTESIAN_MOTION_FORCE: "RT_CARTESIAN_MOTION_FORCE",
            cls.NRT_CARTESIAN_MOTION_FORCE: "NRT_CARTESIAN_MOTION_FORCE",
            cls.NRT_SUPER_PRIMITIVE: "NRT_SUPER_PRIMITIVE",
        }
        return mode_map.get(mode, "UNKNOWN")


class OperationalStatus:
    """运行状态枚举"""
    NOT_READY = 0
    READY = 1
    FAULT = 2
    REDUCED = 3
    RECOVERY = 4


# 核心工具类（封装原utility功能）
class Utils:
    """工具函数封装类"""
    @staticmethod
    def quat_to_euler_zyx(quat: List[float]) -> np.ndarray:
        """四元数转ZYX欧拉角（弧度）"""
        q = np.array(quat, dtype=np.float64)
        w, x, y, z = q
        # 内部使用numpy实现转换（解耦Eigen）
        sinr_cosp = 2 * (w * x + y * z)
        cosr_cosp = 1 - 2 * (x**2 + y**2)
        roll = np.arctan2(sinr_cosp, cosr_cosp)

        sinp = 2 * (w * y - z * x)
        pitch = np.arcsin(np.clip(sinp, -1.0, 1.0))

        siny_cosp = 2 * (w * z + x * y)
        cosy_cosp = 1 - 2 * (y**2 + z**2)
        yaw = np.arctan2(siny_cosp, cosy_cosp)

        return np.array([roll, pitch, yaw])

    @staticmethod
    def rad_to_deg(rad: Union[float, np.ndarray]) -> Union[float, np.ndarray]:
        """弧度转角度"""
        return rad * 180.0 / np.pi

    @staticmethod
    def deg_to_rad(deg: Union[float, np.ndarray]) -> Union[float, np.ndarray]:
        """角度转弧度"""
        return deg * np.pi / 180.0

    @staticmethod
    def vec2str(vec: List[Any], decimal: int = 3, separator: str = " ") -> str:
        """向量转字符串"""
        fmt = f".{decimal}f" if isinstance(vec[0], (int, float)) else "%s"
        return separator.join([f"{x:{fmt}}" for x in vec])

    @staticmethod
    def program_args_exist(arg_list: List[str], target: str) -> bool:
        """检查程序参数是否存在"""
        return target in arg_list


# 机器人核心接口封装
class Robot:
    """机器人主控制接口"""
    def __init__(self, robot_sn: str, network_interface_whitelist: List[str] = None, verbose: bool = True):
        self.robot_sn = robot_sn
        self.network_interfaces = network_interface_whitelist or []
        self.verbose = verbose
        self._connected = False
        self._mode = Mode.UNKNOWN
        self._states = None  # 实际实现中会存储机器人状态

    def connect(self) -> bool:
        """建立连接"""
        # 实现连接逻辑
        self._connected = True
        return self._connected

    def disconnect(self) -> None:
        """断开连接"""
        self._connected = False

    @property
    def connected(self) -> bool:
        """是否已连接"""
        return self._connected

    def switch_mode(self, mode: Mode) -> bool:
        """切换控制模式"""
        if not self._connected:
            raise RuntimeError("Robot not connected")
        self._mode = mode
        return True

    def enable(self) -> None:
        """使能机器人"""
        if not self._connected:
            raise RuntimeError("Robot not connected")
        # 实现使能逻辑

    def stop(self) -> None:
        """停止机器人"""
        # 实现停止逻辑

    def states(self) -> Dict[str, Any]:
        """获取机器人状态"""
        # 返回状态字典
        return self._states


# 工具管理接口
class ToolManager:
    """工具管理接口"""
    def __init__(self, robot: Robot):
        self._robot = robot
        self._tools: Dict[str, ToolParams] = {}  # 存储工具参数

    def list(self) -> List[str]:
        """获取所有工具列表"""
        if not self._robot.connected:
            raise RuntimeError("Robot not connected")
        return list(self._tools.keys())

    def exist(self, name: str) -> bool:
        """检查工具是否存在"""
        return name in self._tools

    def get_params(self, name: str) -> ToolParams:
        """获取工具参数"""
        if not self.exist(name):
            raise ValueError(f"Tool {name} not found")
        return self._tools[name]

    def add(self, name: str, params: ToolParams) -> None:
        """添加新工具"""
        if self.exist(name):
            raise ValueError(f"Tool {name} already exists")
        if self._robot.mode != Mode.IDLE:
            raise RuntimeError("Robot must be in IDLE mode to add tool")
        self._tools[name] = params

    def update(self, name: str, params: ToolParams) -> None:
        """更新工具参数"""
        if not self.exist(name):
            raise ValueError(f"Tool {name} not found")
        self._tools[name] = params

    def remove(self, name: str) -> None:
        """移除工具"""
        if name == "Flange":
            raise ValueError("Cannot remove Flange tool")
        if not self.exist(name):
            raise ValueError(f"Tool {name} not found")
        del self._tools[name]

    def calibrate_payload(self, tool_mounted: bool) -> ToolParams:
        """校准负载参数"""
        if self._robot.mode != Mode.IDLE:
            raise RuntimeError("Robot must be in IDLE mode for calibration")
        # 实现校准逻辑
        return ToolParams()


# 模型接口封装（解耦Eigen）
class RobotModel:
    """机器人模型接口（运动学/动力学）"""
    def __init__(self, robot: Robot, gravity: List[float] = None):
        self._robot = robot
        self._gravity = np.array(gravity) if gravity else np.array([0, 0, -9.81])
        self._mass_matrix = None
        self._jacobian = None

    def reload(self) -> None:
        """重新加载模型参数"""
        if not self._robot.connected:
            raise RuntimeError("Robot not connected")
        # 实现模型重载逻辑

    def update(self, positions: List[float], velocities: List[float]) -> None:
        """更新机器人配置"""
        q = np.array(positions)
        qd = np.array(velocities)
        # 实现配置更新逻辑

    def jacobian(self, link_name: str) -> np.ndarray:
        """获取雅可比矩阵"""
        # 内部使用numpy计算，对外返回ndarray但封装实现细节
        return np.zeros((6, 7))  # 示例维度

    def mass_matrix(self) -> np.ndarray:
        """获取质量矩阵"""
        return np.eye(7)  # 示例矩阵


# 其他接口封装
class Maintenance:
    """维护操作接口"""
    def __init__(self, robot: Robot):
        self._robot = robot

    def calibrate_joint_torque_sensors(self, cali_posture: List[float] = None) -> None:
        """校准关节力矩传感器"""
        if self._robot.mode != Mode.IDLE:
            raise RuntimeError("Robot must be in IDLE mode for calibration")
        # 实现校准逻辑


class FileIO:
    """文件IO接口"""
    def __init__(self, robot: Robot):
        self._robot = robot

    def list_traj_files(self) -> List[str]:
        """列出轨迹文件"""
        return []  # 实现文件列表逻辑

    def upload_traj_file(self, file_dir: str, file_name: str) -> None:
        """上传轨迹文件"""
        # 实现上传逻辑

    def download_traj_file(self, file_name: str, save_dir: Optional[str] = None) -> Union[str, None]:
        """下载轨迹文件"""
        # 实现下载逻辑
        return ""


class WorkCoordManager:
    """工作坐标管理接口"""
    def __init__(self, robot: Robot):
        self._robot = robot
        self._work_coords: Dict[str, Pose] = {}

    def list(self) -> List[str]:
        """列出所有工作坐标"""
        return list(self._work_coords.keys())

    def add(self, name: str, pose: Pose) -> None:
        """添加工作坐标"""
        if name in self._work_coords:
            raise ValueError(f"Work coordinate {name} already exists")
        self._work_coords[name] = pose

    def update(self, name: str, pose: Pose) -> None:
        """更新工作坐标"""
        if name not in self._work_coords:
            raise ValueError(f"Work coordinate {name} not found")
        self._work_coords[name] = pose

    def get_pose(self, name: str) -> Pose:
        """获取工作坐标位姿"""
        if name not in self._work_coords:
            raise ValueError(f"Work coordinate {name} not found")
        return self._work_coords[name]