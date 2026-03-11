from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class BasicForceControl:
    class ZeroFTSensor(Primitive):
        PT_NAME = "CaliForceSensor"
        PT_TYPE = "CALIFORCESENSOR"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class InputParams:
            class Basic(Enum):
                DataCollectTime = "dataCollectionTime"
                EnableStaticCheck = "enableStaticCheck"

            class Advanced(Enum):
                CalibExtraPayload = "calibrateExtraLoad"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class Contact(Primitive):
        PT_NAME = "Contact"
        PT_TYPE = "CONTACT"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            CurContactForce = "curContactForce"
            ForwardDis = "insertDis"

        class InputParams:
            class Basic(Enum):
                ContactCoord = "coord"
                ContactDir = "movingDir"
                ContactVel = "contactVel"
                MaxContactForce = "maxContactForce"
                EnableFineContact = "fineContactMode"

            class Advanced(Enum):
                Waypoints = "waypoints"
                Vel = "maxVel"
                Acc = "maxAcc"
                ZoneRadius = "zoneRadius"
                Jerk = "maxJerk"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class ForceHybridLite(Primitive):
        PT_NAME = "MoveHybridLite"
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
                Vel = "maxVel"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"
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
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class ForceCompLite(Primitive):
        PT_NAME = "MoveCompliance"
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
                CompAxis = "compAxis"

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