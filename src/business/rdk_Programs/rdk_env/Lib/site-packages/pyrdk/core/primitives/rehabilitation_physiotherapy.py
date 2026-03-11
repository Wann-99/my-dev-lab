from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class RehabilitationPhysiotherapy:
    class Massage(Primitive):
        PT_NAME = "Massage"
        PT_TYPE = "MOVEHYBRID"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"
            WaypointIndex = "waypointIndex"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                TargetWrench = "goalWrench"
                Waypoints = "waypoints"
                Wrench = "wrench"
                Vel = "maxVel"
                ZoneRadius = "zoneRadius"
                TargetTolerLevel = "targetTolLevel"
                ForceCoord = "forceCoord"
                ForceAxis = "forceAxis"
                StiffScale = "stiffnessScaling"
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                EnableEntryPoint = "enableEntry"
                MaxWrenchPause = "pauseAtMaxWrench"
                MotionForceDecouple = "decoupleActuation"
                WrenchFilterCutoff = "wrenchFilterCutoff"

            class Advanced(Enum):
                Acc = "maxAcc"
                Jerk = "maxJerk"
                AngVel = "maxW"
                EnableFixRefJntPos = "enablePreferJntPos"
                RefJntPos = "preferJntPos"
                ConfigOptObj = "nullspaceGradientScaling"
                MaxVelForceDir = "maxVelForceDir"
                LineSpace = "lineSpace"
                Amplitude = "amplitude"
                Pitch = "pitch"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)