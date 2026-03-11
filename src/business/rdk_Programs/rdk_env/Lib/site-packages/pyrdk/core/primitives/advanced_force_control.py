from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class AdvancedForceControl:
    class ContactAlign(Primitive):
        PT_NAME = "AlignContact"
        PT_TYPE = "ALIGNCONTACT"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            AlignContacted = "alignContacted"
            ForwardDis = "insertDis"

        class InputParams:
            class Basic(Enum):
                ContactAxis = "contactDir"
                ContactVel = "freeSpaceVel"
                ContactForce = "targetForce"
                AlignAxis = "alignmentDir"
                AlignVelScale = "alignVelScale"

            class Advanced(Enum):
                DeadbandScale = "deadbandScale"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class ForceTraj(Primitive):
        PT_NAME = "MoveTraj"
        PT_TYPE = "MOVE_TRAJ"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                TrajFileName = "fileName"
                TargetTolerLevel = "targetTolLevel"
                ForceCoord = "forceCoord"
                ForceAxis = "forceAxis"

            class Advanced(Enum):
                ConfigOptObj = "nullspaceGradientScaling"
                MaxVelForceDir = "maxVelForceDir"
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                Jerk = "maxJerk"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class ForceHybrid(Primitive):
        PT_NAME = "MoveHybrid"
        PT_TYPE = "MOVEHYBRID"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                Waypoints = "waypoints"
                Wrench = "wrench"
                Vel = "maxVel"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"
                ForceCoord = "forceCoord"
                ForceAxis = "forceAxis"
                TargetWrench = "goalWrench"
                StiffScale = "stiffnessScaling"

            class Advanced(Enum):
                Acc = "maxAcc"
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                Jerk = "maxJerk"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class ForceComp(Primitive):
        PT_NAME = "ForceCompliance"
        PT_TYPE = "MOVE_COMPLIANCE"

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
                CompCoord = "compCoord"
                StiffScale = "stiffnessScaling"

            class Advanced(Enum):
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
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