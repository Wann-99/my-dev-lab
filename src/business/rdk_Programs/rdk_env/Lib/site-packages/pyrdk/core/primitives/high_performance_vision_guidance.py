from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class HighPerformanceVisionGuidance:
    class VSTeach(Primitive):
        PT_NAME = "VisualServoTeach"
        PT_TYPE = "VISUALSERVOTEACH"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            TeachFinished = "teachFinished"

        class InputParams:
            class Basic(Enum):
                ObjName = "objName"
                ObjIndex = "objIdx"
                CollectTimes = "sampleNum"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"
            TaughtFeaturePts2D = "taughtFeaturePts2D"
            TaughtAlignPts2D = "taughtMatchPts2D"
            TaughtFeaturePtsNoise = "taughtFeaturePtsNoise"
            TaughtFeaturePts3D = "taughtFeaturePts3D"
            TaughtAlignPts3D = "taughtMatchPts3D"
            TaughtObjPose = "taughtObjPose"
            TaughtAlignPose = "taughtMatchPose"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class HPImageBasedVS(Primitive):
        PT_NAME = "IBVS"
        PT_TYPE = "IBVS"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ObjAligned = "reachedTarget"

        class InputParams:
            class Basic(Enum):
                ObjName = "objName"
                ObjIndex = "objIdx"
                TargetFeaturePts = "targetFeaturePoints"
                TargetDepth = "targetDepth"
                VsAxis = "vsAxis"
                VelScale = "velScale"
                MaxVel = "maxVel"
                MaxAngVel = "maxRotVel"
                ImageConvToler = "imgConvTol"
                TargetConvTimes = "countTol"
                TimeoutTime = "timeoutTime"

            class Advanced(Enum):
                EnableObjAlign = "enableObjAlign"
                AlignObjPts = "targetMatchObjPts"
                OptVelScale = "optVelScale"
                VisualDetectNoise = "AIDetectNoise"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class HPPoseBasedVS(Primitive):
        PT_NAME = "PBVS"
        PT_TYPE = "PBVS"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ObjAligned = "reachedTarget"

        class InputParams:
            class Basic(Enum):
                ObjName = "objName"
                ObjIndex = "objIdx"
                DetectObjPose = "enableObjPose"
                TargetObjPose = "targetObjectPose"
                VsCoord = "visualCoord"
                VsAxis = "vsAxis"
                VelScale = "velScale"
                MaxVel = "maxVel"
                MaxAcc = "maxAcc"
                TimeoutTime = "timeoutTime"
                VisualDelayTime = "compensateDelayTime"
                PosConvToler = "posTol"
                RotConvTimes = "oriTol"
                TargetConvTimes = "countTol"

            class Advanced(Enum):
                TargetFeaturePts = "targetFeaturePoints"
                EnableObjAlign = "enableObjAlign"
                AlignObjPts = "targetMatchFeaturePoints"
                AlignObjPose = "targetMatchPose"
                SuppressOvershoot = "suppressOvershoot"
                DynamicObjTrack = "dynamicObjTrack"
                VisDetectNoiseLevel = "visualDetectNoiseLevel"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class HPOffsetServo(Primitive):
        PT_NAME = "OBVS"
        PT_TYPE = "OBVS"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ObjAligned = "reachedTarget"

        class InputParams:
            class Basic(Enum):
                ObjName = "objName"
                ObjIndex = "objIdx"
                Target = "target"
                VsCoord = "vsCoord"
                VsAxis = "vsAxis"
                VelScale = "velScale"
                MaxVel = "maxVel"
                MaxAcc = "maxAcc"
                TimeoutTime = "timeoutTime"
                VisualDelayTime = "visualDelayTime"
                PosConvToler = "posConvToler"
                RotConvTimes = "rotConvToler"
                TargetConvTimes = "countTol"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)