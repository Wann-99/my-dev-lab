from pyrdk.enums import TrajFrameValueEnum
from pyrdk.enums import TcpFrameValueEnum
from pyrdk.enums import WorldFrameValueEnum


class TrajFrameType:
    def __init__(self, value: TrajFrameValueEnum = TrajFrameValueEnum.Start):
        self.frame_name: str = "TRAJ"
        self.frame_value: str = value.value


class WorldFrameType:
    def __init__(self):
        self.frame_name: str = "WORLD"
        self.frame_value: str = WorldFrameValueEnum.World_Origin.value


class TcpFrameType:
    def __init__(self, value: TcpFrameValueEnum = TcpFrameValueEnum.Start):
        self.frame_name: str = "TCP"
        self.frame_value: str = value.value


class WorkFrameType:
    def __init__(self, value: str):
        self.frame_name: str = "WORK"
        self.frame_value: str = value


class GVARFrameType:
    def __init__(self, value: str):
        self.frame_name: str = "GVAR"
        self.frame_value: str = value
