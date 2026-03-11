from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class AdaptiveAssembly:
    class SearchHole(Primitive):
        PT_NAME = "SearchHole"
        PT_TYPE = "SEARCH_HOLE"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            SearchResisForce = "searchResistanceForce"
            PushDis = "timePeriod"
            ForceDrop = "forceDrop"
            LostContact = "lostContact"

        class InputParams:
            class Basic(Enum):
                ContactAxis = "contactAxis"
                ContactForce = "contactForce"
                SearchAxis = "searchAxis"
                SearchPattern = "patternType"
                SpiralRadius = "radius"
                ZigZagLength = "length"
                ZigZagWidth = "height"
                StartDensity = "startDensity"
                TimeFactor = "timeFactor"
                WiggleRange = "wiggleRange"
                WigglePeriod = "wigglePeriod"

            class Advanced(Enum):
                EnableMaxWrench = "enableMaxContactWrench"
                MaxContactWrench = "maxContactWrench"
                SearchImmed = "startSearchImmediately"
                SearchStiffRatio = "searchStiffnessRatio"
                MaxVelForceDir = "forceCtrlVelLimit"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class CheckPiH(Primitive):
        PT_NAME = "PihCheckTran"
        PT_TYPE = "PIH_CHECK_TRAN"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            CheckComplete = "checkComplete"
            PegIsInHole = "pegIsInHole"

        class InputParams:
            class Basic(Enum):
                ContactAxis = "contactAxis"
                SearchAxis = "searchAxis"
                SearchRange = "searchRange"
                SearchForce = "searchForce"
                SearchVel = "searchVelocity"

            class Advanced(Enum):
                LinearSearchOnly = "lineSearchOnly"
                ReturnToInitPose = "returnToInitPose"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"
            InitTcpPose = "initTcpPose"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class InsertComp(Primitive):
        PT_NAME = "Sleeve"
        PT_TYPE = "SLEEVE"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            IsMoving = "isMoving"
            InsertDis = "insertDis"

        class InputParams:
            class Basic(Enum):
                InsertAxis = "insertDir"
                CompAxis = "alignmentDir"
                MaxContactForce = "maxContactForce"
                InsertVel = "insertVel"

            class Advanced(Enum):
                DeadbandScale = "deadbandScale"
                CompVelScale = "adjustVelScale"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class Mate(Primitive):
        PT_NAME = "Mating"
        PT_TYPE = "MATING"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            MatingFinish = "matingFinished"

        class InputParams:
            class Basic(Enum):
                ContactAxis = "forceDir"
                StiffScale = "stiffnessScaling"
                ContactForce = "matingForce"
                MatingAxis = "matingDir"
                SlideMatingRange = "linearMatingRange"
                SlideMatingVel = "maxLinearMatingVel"
                SlideMatingAcc = "maxLinearMatingAcc"
                RotateMatingRange = "angularMatingRange"
                RotateMatingVel = "maxAngularMatingVel"
                RotateMatingAcc = "maxAngularMatingAcc"
                MatingTimes = "totalMatingTimes"
                MaxContactDis = "maxMotionDisInForceDir"
                SafetyForce = "safetyForce"

            class Advanced(Enum):
                AddMatingAxis = "rasterDir"
                AddSlideMatingRange = "linearRasterRange"
                AddSlideMatingVel = "maxLinearRasterVel"
                AddSlideMatingAcc = "maxLinearRasterAcc"
                AddRotateMatingRange = "angularRasterRange"
                AddRotateMatingVel = "maxAngularRasterVel"
                AddRotateMatingAcc = "maxAngularRasterAcc"
                MaxVelForceDir = "maxVelInForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class FastenScrew(Primitive):
        PT_NAME = "ScrewFasten"
        PT_TYPE = "SCREWFASTEN"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            InsertDis = "insertDis"
            InsertVel = "insertVel"
            FastenState = "fastenState"
            ReachedHole = "reachedScrewHole"

        class InputParams:
            class Basic(Enum):
                InsertDir = "insertDir"
                MaxInsertVel = "insertVel"
                InsertForce = "maxContactForce"
                StiffScale = "stiffnessScale"

            class Advanced(Enum):
                DiScrewInHole = "ioScrewInHole"
                DiFastenFinish = "ioFinish"
                DiScrewJam = "ioScrewJam"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)