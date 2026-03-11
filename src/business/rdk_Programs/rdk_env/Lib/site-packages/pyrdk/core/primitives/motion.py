from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class Motion:
    class MoveC(Primitive):
        PT_NAME = "MoveC"
        PT_TYPE = "MOVEC"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                MiddlePose = "middlePose"
                Vel = "maxVel"
                TargetTolerLevel = "targetTolLevel"

            class Advanced(Enum):
                Acc = "maxAcc"
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                Jerk = "maxJerk"
                ConfigOptObj = "nullspaceGradientScaling"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class MoveJ(Primitive):
        PT_NAME = "MoveJ"
        PT_TYPE = "MOVEJ"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                Waypoints = "waypoints"
                JntVelScale = "jntVelScale"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"

            class Advanced(Enum):
                EnableRelativeMove = "relativeToStart"
                JntAccMultiplier = "jntAccMultiplier"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class MoveL(Primitive):
        PT_NAME = "MoveL"
        PT_TYPE = "MOVEL"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                Waypoints = "waypoints"
                Vel = "maxVel"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"

            class Advanced(Enum):
                Acc = "maxAcc"
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                Jerk = "maxJerk"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableSixAxisJntCtrl = "enableSixJointAxesCtrl"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class MovePTP(Primitive):
        PT_NAME = "MovePTP"
        PT_TYPE = "MOVEPTP"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                Waypoints = "waypoints"
                JntVelScale = "jntVelScale"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"

            class Advanced(Enum):
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                JntAccMultiplier = "jntAccMultiplier"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class MoveJTraj(Primitive):
        PT_NAME = "MoveJTraj"
        PT_TYPE = "MOVEJTRAJ"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                TrajFileName = "fileName"
                JntVelScale = "jntVelScale"
                TargetTolerLevel = "targetTolLevel"

            class Advanced(Enum):
                JntAccMultiplier = "jntAccMultiplier"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)