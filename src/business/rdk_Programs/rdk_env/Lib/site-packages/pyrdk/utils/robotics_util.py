import math
from decimal import Decimal, ROUND_DOWN
from typing import List

from scipy.spatial.transform import Rotation


class RoboticsUtil:

    @staticmethod
    def rad_to_deg(radian: float, precision: int = 4) -> float:
        """
        弧度转角度
        :param radian: 弧度
        :param precision: 精度位数
        :return:
        """
        deg = math.degrees(radian)
        deg = Decimal(deg).quantize(Decimal(f'1.{"0"*precision}'), rounding=ROUND_DOWN)
        return float(deg)

    @staticmethod
    def deg_to_rad(degree: float, precision: int = 8) :
        """
        角度转弧度
        :param degree: 角度
        :param precision: 精度位数
        :return:
        """
        rad = math.radians(degree)
        rad = Decimal(rad).quantize(Decimal(f'1.{"0"*precision}'), rounding=ROUND_DOWN)
        return float(rad)

    @staticmethod
    def euler_to_quat(euler: List[float]) -> List[float]:
        """
        将欧拉角转为四元素
        :param euler: [rz, ry, rx]
        :return: [w, x, y, z]
        """
        r_from_euler = Rotation.from_euler("xyz", euler, degrees=True)
        quat = r_from_euler.as_quat().tolist()
        return [quat[3], quat[0], quat[1], quat[2]]

    @staticmethod
    def quat_to_euler_zyx(quat: List[float]) -> List[float]:
        """
        将四元素转化为欧拉角 ZYX axis rotations.
        :param quat: [w, x, y, z]
        :return: [rx, ry, rz]
        """
        r = Rotation.from_quat(
            [quat[1], quat[2], quat[3], quat[0]]
        )  # scipy uses [x,y,z,w] order
        euler = r.as_euler("xyz", degrees=True).tolist()
        return euler
