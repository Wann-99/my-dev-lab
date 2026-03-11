from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class ZeroGravityFloating:
    class FloatingCartesian(Primitive):
        PT_NAME = "FloatingCartesian"
        PT_TYPE = "CARTIMPEDANCEFLOATING"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            IdleTime = "idleTime"

        class InputParams:
            class Basic(Enum):
                FloatingAxis = "cartFloatingAxis"
                EnableElbowMotion = "enableJointFloating"
                FloatingCoord = "floatingCoord"
                DampingLevel = "resistanceLevel"

            class Advanced(Enum):
                DiEnableFloating = "diEnableFloating"
                ResponseTorque = "jointTorqueDeadBand"
                InertiaScale = "inertiaScale"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class FloatingJoint(Primitive):
        PT_NAME = "FloatingJoint"
        PT_TYPE = "JNTIMPEDANCEFLOATING"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            IdleTime = "idleTime"

        class InputParams:
            class Basic(Enum):
                FloatingJoint = "jntFloatingAxis"
                DampingLevel = "resistanceLevel"

            class Advanced(Enum):
                ResponseTorque = "jointTorqueDeadBand"
                DiEnableFloating = "diEnableFloating"
                InertiaScale = "inertiaScale"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)