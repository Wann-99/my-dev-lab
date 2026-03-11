from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class Showcase:
    class BalanceBall(Primitive):
        PT_NAME = "BallBalance"
        PT_TYPE = "MPCBALLBALANCING"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class InputParams:
            class Basic(Enum):
                BallWeight = "ballWeight"
                BallFricCoeff = "ballFrictionCoeff"
                PattenType = "trajType"
                COPOffsetX = "COPOffsetX"
                COPOffsetY = "COPOffsetY"

            class Advanced(Enum):
                PattenSizeScale = "pathScale"
                FreScale = "freScale"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class BalanceGlasses(Primitive):
        PT_NAME = "BalanceGlasses"
        PT_TYPE = "BALANCEGLASSES"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                Duration = "duration"
                Waypoints = "waypoints"
                TargetTolerLevel = "targetTolLevel"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)