from typing import Optional
import serial
import time


class TxCmdEnum:
    TRANSPORT_WEIGH_485_TO_TX = "TRANSPORT_WEIGH_485_TO_TX"


class TxClient:
    def __init__(self, serial_port: str, baudrate: int = 115200, timeout: float = 2.0):
        """
        初始化串口客户端，模拟RS485硬件通信
        :param serial_port: 串口名称，如Windows的"COM3"，Linux的"/dev/ttyUSB0"
        :param baudrate: 波特率，默认115200（协议默认值）
        :param timeout: 串口超时时间
        """
        self.ser = serial.Serial(
            port=serial_port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=timeout
        )
        self.timeout = timeout

    def send_and_wait(self, cmd: str, payload: bytes, expected_length: Optional[int] = None, timeout: Optional[float] = None) -> bytes:
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        self.ser.write(payload)
        time.sleep(0.001)
        start_time = time.time()
        deadline = start_time + (self.timeout if timeout is None else timeout)
        received = b""
        while time.time() < deadline:
            waiting = self.ser.in_waiting
            if waiting > 0:
                if expected_length:
                    to_read = min(waiting, max(0, expected_length - len(received)))
                    if to_read > 0:
                        received += self.ser.read(to_read)
                    if len(received) >= expected_length:
                        break
                else:
                    received += self.ser.read(waiting)
            else:
                time.sleep(0.001)
        return received

    def close(self):
        if self.ser.is_open:
            self.ser.close()

def to_hex(b: bytes) -> str:
    return " ".join(f"{x:02X}" for x in b)


FRAME_HEADER = 0x3E
SINGLE_TURN_CMD_V2 = 0xA6
READ_SINGLE_ANGLE_CMD = 0x94
SET_ZERO_POINT_CMD = 0x19
DEFAULT_MOTOR_ID = 1
MAX_SPEED = 60000
REDUCTION = 8
SPEED = 50


class TxRS485MotorExecute:
    def __init__(self, tx_client: TxClient):
        self.tx_client = tx_client

    def sendSingleTurnPositionCommandV2_full(self, motorId: int, clockwise: bool, targetAngle: float, speedPercentage: int) -> None:
        if motorId < 0x01 or motorId > 0x20:
            raise ValueError("Invalid motor ID (1-32)")
        if speedPercentage < 0 or speedPercentage > 100:
            raise ValueError("Speed percentage must be 0-100")
        if targetAngle < 0.0 or targetAngle > 359.99:
            raise ValueError("Target angle must be 0-359.99")

        frame_cmd = bytearray(5)
        frame_cmd[0] = FRAME_HEADER
        frame_cmd[1] = SINGLE_TURN_CMD_V2
        frame_cmd[2] = motorId & 0xFF
        frame_cmd[3] = 0x08
        frame_cmd[4] = self._checksum(frame_cmd, 0, 4)

        frame_data = bytearray(9)
        frame_data[0] = 0x00 if clockwise else 0x01
        angle_control = int(targetAngle * REDUCTION * 100)
        frame_data[1] = angle_control & 0xFF
        frame_data[2] = (angle_control >> 8) & 0xFF
        frame_data[3] = (angle_control >> 16) & 0xFF
        max_speed = int(MAX_SPEED * (float(speedPercentage) / 100.0))
        frame_data[4] = max_speed & 0xFF
        frame_data[5] = (max_speed >> 8) & 0xFF
        frame_data[6] = (max_speed >> 16) & 0xFF
        frame_data[7] = (max_speed >> 24) & 0xFF
        frame_data[8] = self._checksum(frame_data, 0, 8)

        full_command = bytes(frame_cmd + frame_data)
        print(f"TX: {to_hex(full_command)}")
        rx = self.tx_client.send_and_wait(TxCmdEnum.TRANSPORT_WEIGH_485_TO_TX, full_command)
        if rx:
            print(f"RX: {to_hex(rx)}")





    def smartReturnToZero(self, motorId: int = DEFAULT_MOTOR_ID) -> None:
        current_angle = self.readSingleTurnAngle(motorId)
        clockwise_distance = (360.0 - current_angle) % 360.0
        if clockwise_distance < current_angle:
            clockwise = True
        elif clockwise_distance > current_angle:
            clockwise = False
        else:
            clockwise = current_angle < 180.0
        self.sendSingleTurnPositionCommandV2_full(motorId, clockwise, 0.0, SPEED)

    def readSingleTurnAngle(self, motorId: int = DEFAULT_MOTOR_ID) -> float:
        if motorId < 0x01 or motorId > 0x20:
            raise ValueError("Invalid motor ID (1-32)")

        tx_frame = bytearray(5)
        tx_frame[0] = FRAME_HEADER
        tx_frame[1] = READ_SINGLE_ANGLE_CMD
        tx_frame[2] = motorId & 0xFF
        tx_frame[3] = 0x00
        tx_frame[4] = self._checksum(tx_frame, 0, 4)

        rx = self.tx_client.send_and_wait(TxCmdEnum.TRANSPORT_WEIGH_485_TO_TX, bytes(tx_frame), expected_length=10)
        if len(rx) < 10:
            raise IOError("Invalid reply length")
        
        cmd_sum = self._checksum(rx, 0, 4)
        if cmd_sum != rx[4]:
            raise IOError("Frame command checksum error: readSingleTurnAngle")
        
        data_sum = self._checksum(rx, 5, 4)
        if data_sum != rx[9]:
            raise IOError("Frame data checksum error")
        
        raw_value = (rx[5] & 0xFF) | ((rx[6] & 0xFF) << 8) | ((rx[7] & 0xFF) << 16) | ((rx[8] & 0xFF) << 24)
        return (raw_value * 0.01) / REDUCTION

    def setCurrentPositionAsZeroPoint(self, motorId: int = DEFAULT_MOTOR_ID) -> int:
        if motorId < 0x01 or motorId > 0x20:
            raise ValueError("Invalid motor ID (1-32)")

        tx_frame = bytearray(5)
        tx_frame[0] = FRAME_HEADER
        tx_frame[1] = SET_ZERO_POINT_CMD
        tx_frame[2] = motorId & 0xFF
        tx_frame[3] = 0x00
        tx_frame[4] = self._checksum(tx_frame, 0, 4)

        rx = self.tx_client.send_and_wait(TxCmdEnum.TRANSPORT_WEIGH_485_TO_TX, bytes(tx_frame), expected_length=7)
        if len(rx) < 7:
            raise IOError("Invalid reply length")
        
        cmd_sum = self._checksum(rx, 0, 4)
        if cmd_sum != rx[4]:
            raise IOError("Frame command checksum error: setCurrentPositionAsZeroPoint")
        
        return (rx[5] & 0xFF) | ((rx[6] & 0xFF) << 8)

    def _checksum(self, data: bytes, offset: int, length: int) -> int:
        s = 0
        for i in range(offset, offset + length):
            s += data[i] & 0xFF
        return s & 0xFF


if __name__ == "__main__":
    # 示例：替换为实际串口名称
    SERIAL_PORT = "COM4"  # Windows示例，Linux请改为"/dev/ttyUSB0"等
    try:
        # 初始化串口客户端
        tx_client = TxClient(serial_port=SERIAL_PORT)
        # 初始化电机执行器
        motor_exec = TxRS485MotorExecute(tx_client)
        
        # 1. 读取当前单圈角度
        # current_angle = motor_exec.readSingleTurnAngle()
        # print(f"当前电机单圈角度（已换算减速比）: {current_angle:.2f}°")
        
        # 2. 智能回零
        # print("执行智能回零...")
        # motor_exec.smartReturnToZero()
        # time.sleep(2)  # 等待电机动作完成
        # zero_angle = motor_exec.readSingleTurnAngle()
        # print(f"回零后角度: {zero_angle:.2f}°")
        
        # 3. 发送单圈位置指令（顺时针转到45°，速度50%）
        motor_exec.sendSingleTurnPositionCommandV2_full(DEFAULT_MOTOR_ID, True, 70, 50)
        time.sleep(0.1)
        target_angle = motor_exec.readSingleTurnAngle()
        print(f"到达目标位置后角度: {target_angle:.2f}°")
        
        
        # 5. 设置当前位置为零点（谨慎使用，会写入ROM）
        # print("设置当前位置为零点...")
        # zero_encoder = motor_exec.setCurrentPositionAsZeroPoint()
        # print(f"零点编码器原始值: {zero_encoder}")

    except Exception as e:
        print(f"运行出错: {str(e)}")
    finally:
        # 关闭串口
        if 'tx_client' in locals():
            tx_client.close()
            print("串口已关闭")
