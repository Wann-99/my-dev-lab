from flexivrdk import JPos
from flexivrdk import Coord
from pyrdk.core.frame import TcpFrameType, GVARFrameType, WorldFrameType, WorkFrameType, TrajFrameType


class JointPositionType:
    def __init__(self,
                 a1: float = 0.0,
                 a2: float = 0.0,
                 a3: float = 0.0,
                 a4: float = 0.0,
                 a5: float = 0.0,
                 a6: float = 0.0,
                 a7: float = 0.0,
                 x1: float = 0.0,
                 x2: float = 0.0,
                 x3: float = 0.0,
                 x4: float = 0.0,
                 x5: float = 0.0,
                 x6: float = 0.0):
        self.a1 = a1
        self.a2 = a2
        self.a3 = a3
        self.a4 = a4
        self.a5 = a5
        self.a6 = a6
        self.a7 = a7
        self.x1 = x1
        self.x2 = x2
        self.x3 = x3
        self.x4 = x4
        self.x5 = x5
        self.x6 = x6
        self.value = JPos(
            [self.a1, self.a2, self.a3, self.a4, self.a5, self.a6, self.a7],
            [self.x1, self.x2, self.x3, self.x4, self.x5, self.x6]
        )


class CoordinateType:
    def __init__(self,
                 x: float,
                 y: float,
                 z: float,
                 rx: float,
                 ry: float,
                 rz: float,
                 frame: WorldFrameType | WorkFrameType | TrajFrameType | GVARFrameType | TcpFrameType,
                 ref_a1: float = 0.0,
                 ref_a2: float = 0.0,
                 ref_a3: float = 0.0,
                 ref_a4: float = 0.0,
                 ref_a5: float = 0.0,
                 ref_a6: float = 0.0,
                 ref_a7: float = 0.0,
                 ref_x1: float = 0.0,
                 ref_x2: float = 0.0,
                 ref_x3: float = 0.0,
                 ref_x4: float = 0.0,
                 ref_x5: float = 0.0,
                 ref_x6: float = 0.0
                 ):
        self.x = x
        self.y = y
        self.z = z
        self.rx = rx
        self.ry = ry
        self.rz = rz
        self.frame = frame
        self.ref_a1 = ref_a1
        self.ref_a2 = ref_a2
        self.ref_a3 = ref_a3
        self.ref_a4 = ref_a4
        self.ref_a5 = ref_a5
        self.ref_a6 = ref_a6
        self.ref_a7 = ref_a7
        self.ref_x1 = ref_x1
        self.ref_x2 = ref_x2
        self.ref_x3 = ref_x3
        self.ref_x4 = ref_x4
        self.ref_x5 = ref_x5
        self.ref_x6 = ref_x6

        self.value = Coord(
            [self.x, self.y, self.z],
            [self.rx, self.ry, self.rz],
            [self.frame.frame_name, self.frame.frame_value],
            [self.ref_a1, self.ref_a2, self.ref_a3, self.ref_a4, self.ref_a5, self.ref_a6, self.ref_a7],
            [self.ref_x1, self.ref_x2, self.ref_x3, self.ref_x4, self.ref_x5, self.ref_x6]
        )
