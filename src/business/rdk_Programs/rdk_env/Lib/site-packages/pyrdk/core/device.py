import flexivrdk

from pyrdk.enums import DeviceNameEnum
from pyrdk.robot import Robot


class Device:

    def __init__(self, name: DeviceNameEnum, robot: Robot):
        self.name = name.value
        self.robot = robot
        self._device = flexivrdk.Device(self.robot._robot)

    @property
    def exist(self):
        return self._device.exist(self.name)

    def enable(self):
        return self._device.Enable(self.name)

    def disable(self):
        return self._device.Disable(self.name)

    def command(self, commands: object):
        return self._device.Command(self.name, commands)

    @property
    def params(self):
        return self._device.params(self.name)

    def is_enabled(self):
        return self._device.enabled(self.name)

    def is_connected(self):
        return self._device.connected(self.name)
