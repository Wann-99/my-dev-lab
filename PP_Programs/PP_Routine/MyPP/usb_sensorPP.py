from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import (
    ModbusReadTypeEnum,
    BaudRateEnum,
    PartityEnum,
    DataBitsEnum,
    StopBitsEnum,
)
from pp.core.basic import wait_ms
from pp.core.communication import modbus_rtu_open, modbus_rtu_read, modbus_rtu_close


class UsbSensorPP(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_sensor(self):
        i = 0
        if modbus_rtu_open(
            1,
            "/dev/serusb2",
            BaudRateEnum.BAUD_9600,
            PartityEnum.NONE,
            DataBitsEnum.BIT_8,
            StopBitsEnum.BIT_1,
        ):
            print("Sensor connection successful")
            while i < 1000:
                print(
                    modbus_rtu_read(1, 1, 1, ModbusReadTypeEnum.HOLDING_REGISTERS, 512)
                )
                wait_ms(5)
                i = i + 1
        print("Sensor connection failed")
        modbus_rtu_close(1)
