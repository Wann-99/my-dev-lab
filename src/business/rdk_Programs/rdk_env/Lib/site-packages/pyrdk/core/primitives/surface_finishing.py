from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class SurfaceFinishing:
    class Polish(Primitive):
        PT_NAME = "Polish"
        PT_TYPE = "POLISH"

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
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableForceAutoRot = "enableForceAutoRotation"
                ForceRotAxis = "ForceRotationAxis"
                EnableContactAngle = "enableContactAngle"
                ContactAngle = "contactAngle"
                ContactRotAxis = "rotAxis"
                ContactRotRadius = "rotRadius"
                EnableTrajOverlay = "enableTrajOverlay"
                OverlaidTrajType = "overlaidTrajType"
                Amplitude = "amplitude"
                Pitch = "pitch"
                OverlaidRotAngle = "rotAngle"
                LineSpace = "lineSpace"
                EnableTransLimit = "enableTransLimit"
                MaxTransDisp = "maxTransDisp"
                MinTransDisp = "minTransDisp"
                EnableOrientLimit = "enableOrientLimit"
                ToolRadius = "toolRadius"
                MaxOrientAngle = "maxOrientAngle"
                StiffScale = "stiffnessScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class Grind(Primitive):
        PT_NAME = "Grind"
        PT_TYPE = "GRIND"

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
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableForceAutoRot = "enableForceAutoRotation"
                ForceRotAxis = "ForceRotationAxis"
                EnableContactAngle = "enableContactAngle"
                ContactAngle = "contactAngle"
                ContactRotAxis = "rotAxis"
                ContactRotRadius = "rotRadius"
                EnableTrajOverlay = "enableTrajOverlay"
                OverlaidTrajType = "overlaidTrajType"
                Amplitude = "amplitude"
                Pitch = "pitch"
                OverlaidRotAngle = "rotAngle"
                LineSpace = "lineSpace"
                EnableTransLimit = "enableTransLimit"
                MaxTransDisp = "maxTransDisp"
                MinTransDisp = "minTransDisp"
                EnableOrientLimit = "enableOrientLimit"
                ToolRadius = "toolRadius"
                MaxOrientAngle = "maxOrientAngle"
                StiffScale = "stiffnessScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class PolishECP(Primitive):
        PT_NAME = "PolishECP"
        PT_TYPE = "POLISHECP"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                TrajFileName = "fileName"
                ECPCoord = "ECPCoord"
                TargetTolerLevel = "targetTolLevel"
                ForceAxis = "forceAxis"

            class Advanced(Enum):
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableTrajOverlay = "enableTrajOverlay"
                OverlaidTrajType = "overlaidTrajType"
                Amplitude = "amplitude"
                Pitch = "pitch"
                OverlaidRotAngle = "rotAngle"
                LineSpace = "lineSpace"
                EnableTransLimit = "enableTransLimit"
                MaxTransDisp = "maxTransDisp"
                MinTransDisp = "minTransDisp"
                StiffScale = "stiffnessScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class GrindECP(Primitive):
        PT_NAME = "GrindECP"
        PT_TYPE = "GRINDECP"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                TrajFileName = "fileName"
                ECPCoord = "ECPCoord"
                TargetTolerLevel = "targetTolLevel"
                ForceAxis = "forceAxis"

            class Advanced(Enum):
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                ConfigOptObj = "nullspaceGradientScaling"
                EnableTrajOverlay = "enableTrajOverlay"
                OverlaidTrajType = "overlaidTrajType"
                Amplitude = "amplitude"
                Pitch = "pitch"
                OverlaidRotAngle = "rotAngle"
                LineSpace = "lineSpace"
                EnableTransLimit = "enableTransLimit"
                MaxTransDisp = "maxTransDisp"
                MinTransDisp = "minTransDisp"
                StiffScale = "stiffnessScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                MaxVelForceDir = "maxVelForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)