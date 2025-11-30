import time
import struct
import serial


# ===============================================================
#   TxClient —— 简单串口通信
# ===============================================================
class TxClient:
    def __init__(self, port="COM3", baud=115200, timeout=0.1):
        self.ser = serial.Serial(port, baud, timeout=timeout)
        print(f"串口已打开：{port}, baud={baud}")

    def send_and_wait(self, data: bytes) -> bytes:
        """发送 RS485 数据并等待回复"""
        self.ser.reset_input_buffer()
        self.ser.write(data)

        time.sleep(0.03)  # 适当延时确保电机回复

        recv = self.ser.read(64)
        print("RX:", list(recv))
        return recv


# ===============================================================
#   TxRS485MotorExecute —— 电机控制类
# ===============================================================
class TxRS485MotorExecute:

    FRAME_HEADER = 0x3E
    SINGLE_TURN_CMD_V2 = 0xA6
    READ_SINGLE_ANGLE_CMD = 0x94
    SET_ZERO_POINT_CMD = 0x19
    INCREMENTAL_POS_CMD_V2 = 0xA8

    DEFAULT_MOTOR_ID = 1
    MAX_SPEED = 600000
    SPEED = 50

    def __init__(self, tx_client: TxClient):
        self.tx_client = tx_client

    # ===============================================================
    #   单圈闭环位置控制
    # ===============================================================
    def sendSingleTurnPositionCommandV2(self, motorId=1, clockwise=True,
                                        targetAngle=0.0, speedPercentage=50):

        frameCmd = bytearray(5)
        frameCmd[0] = self.FRAME_HEADER
        frameCmd[1] = self.SINGLE_TURN_CMD_V2
        frameCmd[2] = motorId
        frameCmd[3] = 0x08
        frameCmd[4] = self.calculateChecksum(frameCmd, 0, 4)

        frameData = bytearray(9)
        frameData[0] = 0x00 if clockwise else 0x01

        angleControl = int(targetAngle * 8 * 100)
        frameData[1] = angleControl & 0xFF
        frameData[2] = (angleControl >> 8) & 0xFF
        frameData[3] = int(angleControl / 65532)

        maxSpeed = int(self.MAX_SPEED * (speedPercentage / 100.0))
        frameData[4:8] = struct.pack("<I", maxSpeed)

        frameData[8] = self.calculateChecksum(frameData, 0, 8)

        self.sendCommand(frameCmd, frameData)

    # ===============================================================
    #   增量控制
    # ===============================================================
    def sendIncrementalPositionCommandV2(self, motorId=1, angleIncrementDeg=0.0):

        angleIncrement = int(angleIncrementDeg * 100)
        maxSpeed = int(self.MAX_SPEED * (self.SPEED / 100))

        frameCmd = bytearray([self.FRAME_HEADER,
                              self.INCREMENTAL_POS_CMD_V2,
                              motorId,
                              0x08,
                              0x00])
        frameCmd[4] = self.calculateChecksum(frameCmd, 0, 4)

        frameData = bytearray(9)
        frameData[0:4] = struct.pack("<i", angleIncrement)
        frameData[4:8] = struct.pack("<I", maxSpeed)
        frameData[8] = self.calculateChecksum(frameData, 0, 8)

        self.sendCommand(frameCmd, frameData)

    # ===============================================================
    #   读取角度
    # ===============================================================
    def readSingleTurnAngle(self, motorId=1):
        txFrame = bytearray(5)
        txFrame[0] = self.FRAME_HEADER
        txFrame[1] = self.READ_SINGLE_ANGLE_CMD
        txFrame[2] = motorId
        txFrame[3] = 0x00
        txFrame[4] = self.calculateChecksum(txFrame, 0, 4)

        rx = self.tx_client.send_and_wait(txFrame)

        if len(rx) < 10:
            raise IOError("电机无响应")

        rawValue = struct.unpack("<I", rx[5:9])[0]
        angle = (rawValue * 0.01) / 8.0

        return angle

    # ===============================================================
    #   设置当前为零点
    # ===============================================================
    def setCurrentPositionAsZeroPoint(self, motorId=1):
        txFrame = bytearray(5)
        txFrame[0] = self.FRAME_HEADER
        txFrame[1] = self.SET_ZERO_POINT_CMD
        txFrame[2] = motorId
        txFrame[3] = 0x00
        txFrame[4] = self.calculateChecksum(txFrame, 0, 4)

        rx = self.tx_client.send_and_wait(txFrame)

        zero_raw = struct.unpack("<H", rx[5:7])[0]
        return zero_raw

    # ===============================================================
    #   公共工具
    # ===============================================================
    def sendCommand(self, frameCmd, frameData):
        fullData = frameCmd + frameData
        print("TX:", list(fullData))
        self.tx_client.send_and_wait(fullData)

    def calculateChecksum(self, data, offset, length):
        return sum(data[offset:offset + length]) & 0xFF


# ===============================================================
#   Demo 入口
# ===============================================================
if __name__ == "__main__":

    # 1. 打开串口（修改为你的串口）
    client = TxClient(port="COM3", baud=115200)

    # 2. 加载电机控制器
    motor = TxRS485MotorExecute(client)

    print("\n========== 电机测试开始 ==========\n")

    # 读取当前角度
    print("读取角度中...")
    angle = motor.readSingleTurnAngle()
    print(f"当前角度: {angle:.2f}°")
    time.sleep(0.5)

    # 单圈闭环旋转到 90°
    print("\n旋转到 90° ...")
    motor.sendSingleTurnPositionCommandV2(1, True, 90, 50)
    time.sleep(1)

    # 增量旋转 +45°
    print("\n增量 +45° ...")
    motor.sendIncrementalPositionCommandV2(1, 45)
    time.sleep(1)

    # 设当前为零点
    print("\n设置当前为零点 ...")
    zero_raw = motor.setCurrentPositionAsZeroPoint()
    print("零点 raw =", zero_raw)

    # 再次读取角度
    print("\n重新读取角度...")
    angle = motor.readSingleTurnAngle()
    print(f"新角度: {angle:.2f}°")

    print("\n========== 测试结束 ==========\n")
