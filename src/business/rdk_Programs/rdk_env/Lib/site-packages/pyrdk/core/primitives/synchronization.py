from enum import Enum
from typing import Dict
from pyrdk.core.primitives import Primitive


class Synchronization:
    class SyncStart(Primitive):
        PT_NAME = "SyncStart"
        PT_TYPE = "SYNCSTART"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"
            WorkpieceDetected = "workpieceDetected"

        class InputParams:
            class Basic(Enum):
                SyncDevice = "syncDevice"
                TeachCoord = "teachCoord"

            class Advanced(Enum):
                TrackVel = "maxTrackVel"
                TrackAcc = "maxTrackAcc"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class SyncHold(Primitive):
        PT_NAME = "SyncHold"
        PT_TYPE = "SYNCHOLD"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)

    class SyncEnd(Primitive):
        PT_NAME = "SyncEnd"
        PT_TYPE = "SYNCEND"

        class State(Enum):
            Terminated = "terminated"
            TimePeriod = "timePeriod"

        class InputParams:
            class Basic(Enum):
                SyncDevice = "syncDevice"

        class OutputParams(Enum):
            TcpPoseOut = "tcpPoseOut"

        def __init__(self, params: Dict = None, conditions: Dict = None):
            super().__init__(params=params, conditions=conditions)