class RobotNotOperationalException(Exception):

    def __init__(self):
        self.message = "Robot is not operational in given time"
        super().__init__(self.message)


class RobotSerialNumberException(Exception):

    def __init__(self):
        self.message = "Robot serial number is empty"
        super().__init__(self.message)


class RobotServoOffException(Exception):

    def __init__(self):
        self.message = "Robot must be servo on first"
        super().__init__(self.message)


class RobotEstopNotReleasedException(Exception):

    def __init__(self):
        self.message = "Robot estop not released"
        super().__init__(self.message)


class RobotModeException(Exception):

    def __init__(self):
        self.message = "Robot mode must be auto remote"
        super().__init__(self.message)


class RDKNotCompatibleException(Exception):

    def __init__(self):
        self.message = "Robot's RCA version is not compatible with flexivrdk version"
        super().__init__(self.message)


class PlanNotFoundException(Exception):

    def __init__(self):
        self.message = "Plan not found in current robot"
        super().__init__(self.message)


class RobotFaultNotClearedException(Exception):
    def __init__(self, message="Failed to clear fault"):
        super().__init__(message)


class RobotEnableException(Exception):
    def __init__(self, message="Failed to enable robot"):
        super().__init__(message)


class RobotInRecoveryException(Exception):
    def __init__(self, message="Robot is in recovery mode"):
        super().__init__(message)


class GlobalVariableSetException(Exception):
    def __init__(self):
        self.message = "Failed to set global variable"
        super().__init__(self.message)
