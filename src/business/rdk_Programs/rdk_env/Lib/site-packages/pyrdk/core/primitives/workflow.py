from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class Workflow:
    class Home(Primitive):
        PT_NAME = "Home"
        PT_TYPE = "HOME"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            ReachedTarget = "reachedTarget"

        class InputParams:
            class Basic(Enum):
                Target = "target"
                JntVelScale = "jntVelScale"

            class Advanced(Enum):
                JntAccMultiplier = "jntAccMultiplier"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class Hold(Primitive):
        PT_NAME = "Hold"
        PT_TYPE = "HOLD"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class Fault(Primitive):
        PT_NAME = "Fault"
        PT_TYPE = "FAULT"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class InputParams:
            class Basic(Enum):
                ErrorMessage = "errorMessage"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params, conditions)

    class Stop(Primitive):
        PT_NAME = "Stop"
        PT_TYPE = "STOP"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params, conditions)

    class End(Primitive):
        PT_NAME = "End"
        PT_TYPE = "END"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params, conditions)