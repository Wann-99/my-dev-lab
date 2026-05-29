import os
import numpy as np
from urdfpy import URDF

# =========================
# 1. 获取URDF路径（推荐方式）
# =========================
current_dir = os.path.dirname(os.path.abspath(__file__))
urdf_path = os.path.join(current_dir, "generated_robot_A02L-M4.urdf")

robot = URDF.load(urdf_path)

# =========================
# 2. 关节角（7轴）
# =========================
joint_positions = {
    "joint1": 0.0,
    "joint2": 0.3,
    "joint3": -0.5,
    "joint4": 1.2,
    "joint5": 0.2,
    "joint6": 0.6,
    "joint7": -0.3
}

# =========================
# 3. FK计算
# =========================
link_poses = robot.link_fk(cfg=joint_positions)

T = link_poses[robot.link_map["flange"]]

print("====== 法兰位姿 ======")
print(T)

# =========================
# 4. 拆解
# =========================
position = T[:3, 3]
rotation = T[:3, :3]

print("\n位置:", position)
print("\n旋转矩阵:\n", rotation)