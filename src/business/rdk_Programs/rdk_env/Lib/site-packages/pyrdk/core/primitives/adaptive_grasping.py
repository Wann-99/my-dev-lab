from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class AdaptiveGrasping:
    class GraspComp(Primitive):
        PT_NAME = "AdaptiveGrip"
        PT_TYPE = "ADAPTIVEGRIP"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            CurGripWidth = "curWidth"
            ReachGripForce = "reachedForce"
            ReachGripWidth = "reachedWidth"
            IsGripMoving = "isMoving"
            GripComplete = "graspComplete"

        class InputParams:
            class Basic(Enum):
                GripperType = "gripperType"
                GripVel = "gripSpeed"
                GripWidth = "gripWidth"
                GripForce = "maxGripForce"
                ContactAxis = "contactDir"
                ContactForce = "contactForce"
                CompAxis = "compliantDir"
                CompForce = "compliantForce"

            class Advanced(Enum):
                MaxVelForceDir = "maxVelInForceDir"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)