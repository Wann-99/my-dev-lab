from typing import Dict

import grpc
from pyrdk.log import logger
from pyrdk.settings import ROBOT_GRPC_MIN_RECONNECT_BACKOFF
from pyrdk.settings import ROBOT_GRPC_RETRIES


class RizonGrpcClient:

    def __init__(self, robot_ip: str, robot_grpc_port: int):
        self.robot_ip = robot_ip
        self.robot_grpc_port = robot_grpc_port
        self.channel = grpc.insecure_channel(
            target=f"{self.robot_ip}:{self.robot_grpc_port}",
            options=[
                ("grpc.retries", ROBOT_GRPC_RETRIES),
                ("grpc.min_reconnect_backoff_ms", ROBOT_GRPC_MIN_RECONNECT_BACKOFF),
            ],
        )

    def close(self):
        if self.channel:
            state = self.channel._channel.check_connectivity_state(False)
            if state != grpc.ChannelConnectivity.SHUTDOWN:
                self.channel.close()

    def get_robot_ext_axis_data(self) -> (bool, str):
        """
        获取机器人的外部轴信息
        :return: 没有外部轴信息返回空字符串， 否则返回外部轴品牌和名称， 如 品牌,名称
        """
        from pyrdk.protos.pb2.ExternalAxis_pb2 import ExternalAxisHardWareStateData
        from pyrdk.protos.pb2_grpc.RobotServiceExternalDeviceCfg_pb2_grpc import (
            ExternalDeviceCfgServiceStub,
        )

        try:
            ext_sub = ExternalDeviceCfgServiceStub(self.channel)
            ext_info = ext_sub.GetHardwareExternalAxisStatus(
                ExternalAxisHardWareStateData()
            )
            if (
                    ext_info.has_hardware_external_axis
                    and ext_info.external_axis_connect_status
            ):
                info = ",".join(ext_info.external_axis_name.split(" "))
            else:
                info = ""
            return True, info
        except grpc._channel._InactiveRpcError:
            logger.debug(
                f"{self.robot_ip}:{self.robot_grpc_port} grpc channel connection failed"
            )
            info = ""
        except Exception as e:
            logger.error(f"get robot ext axis error: {e}")
            info = ""
        return False, info

    def get_robot_serial_numbers(self) -> (bool, str):
        """
        获取机器人的序列号信息
        :return: 返回机械臂、控制箱商务序列号
        """
        from pyrdk.protos.pb2.RobotServiceInfo_pb2 import RobotVersionInfo
        from pyrdk.protos.pb2_grpc.RobotServiceInfo_pb2_grpc import InfoServiceStub

        try:
            stub = InfoServiceStub(self.channel)
            version_info = stub.GetRobotVersionInfo(RobotVersionInfo())
            info = version_info.arm_serial_number + "," + version_info.cb_serial_number
            return True, info
        except grpc._channel._InactiveRpcError:
            logger.debug(
                f"{self.robot_ip}:{self.robot_grpc_port} grpc channel connection failed"
            )
            info = ""
        except Exception as e:
            logger.error(f"get robot serial number error: {e}")
            info = ""
        return False, info

    def get_robot_urdf_name(self, robot_model: str) -> (bool, str):
        """
        根据机器人的型号以及是否有外部轴来获取URDF文件名称
        :param robot_model:
        :return:
        """
        ret, ext_axis_info = self.get_robot_ext_axis_data()
        if ret:
            if ext_axis_info == "":
                # 没有外部轴URDF就是序列号的第一段
                urdf_name = robot_model.split("-")[0] + ".urdf"
            else:
                # 存在外部轴，URDF就是 序列号第一段_品牌小写_外部轴名称小写
                urdf_name = (
                        robot_model.split("-")[0]
                        + "_"
                        + ext_axis_info.split(",")[0].lower()
                        + "_"
                        + ext_axis_info.split(",")[1].lower()
                        + ".urdf"
                )
            return True, urdf_name
        return False, ""

    def get_versions(self) -> Dict:
        """
        返回机器人的软件/固件版本信息
        :return:
        """
        from pyrdk.protos.pb2.RobotServiceInfo_pb2 import RobotVersionInfo
        from pyrdk.protos.pb2_grpc.RobotServiceInfo_pb2_grpc import InfoServiceStub

        try:
            stub = InfoServiceStub(self.channel)
            info = stub.GetRobotVersionInfo(RobotVersionInfo())
            version_dict = {
                "abb": info.abb_version,
                "bcb": info.bcb_version,
                "bub": info.bub_version,
                "jxb": ",".join(info.jxb_version),
                "wib": info.wib_version,
                "wsb": info.wsb_version,
                "rca": info.sw_tag_info,
                "arm_driver": info.arm_driver_version,
                "bsp": info.bsp_version,
                "package_version": info.package_version,
                "arm_serial_number": info.raw_arm_serial_number,
                "cb_serial_number": info.raw_cb_serial_number,
                "arm_business_serial_number": info.arm_serial_number,
                "cb_business_serial_number": info.cb_serial_number,
                "is_fs_arm": info.is_fs_arm,
                "is_beta_version": info.is_beta,
            }
            if info.is_fs_arm:
                version_dict.update(
                    {
                        "wsb": info.wsb_version,
                    }
                )
        except grpc._channel._InactiveRpcError:
            logger.debug(
                f"{self.robot_ip}:{self.robot_grpc_port} grpc channel connection failed"
            )
            version_dict = {}
        except Exception as e:
            logger.error(f"get robot version error: {e}")
            version_dict = {}
        return version_dict

    def set_servo_state(self) -> bool:
        """
        机器人只有在servo off状态下，发请求才能servo on;
        但无法让机器人servo off
        :return:
        """
        from pyrdk.protos.pb2.RobotServiceSystem_pb2 import SetServoStateRequest
        from pyrdk.protos.pb2_grpc.RobotServiceSystem_pb2_grpc import SystemServiceStub

        try:
            stub = SystemServiceStub(self.channel)
            ret = stub.SetServoState(SetServoStateRequest())
            logger.debug(f"set servo state return value: {ret.value}, info: {ret.info}")
            return True
        except grpc._channel._InactiveRpcError:
            logger.debug(
                f"{self.robot_ip}:{self.robot_grpc_port} grpc channel connection failed"
            )
            return False
        except Exception as e:
            logger.debug(
                f"robot {self.robot_ip}:{self.robot_grpc_port} cannot connect now: {e}"
            )
            return False

    def get_latest_plan_logger(self, filter: str):
        """
        获取最新的plan logger文件内容, 以filter开头
        :param filter:
        :return:
        """
        from pyrdk.protos.pb2_grpc.RemoteFileSystem_pb2_grpc import RemoteFileSystemServiceStub
        from pyrdk.protos.pb2.RemoteFileSystem_pb2 import FileRequest

        try:
            robot_plan_logger_dir = "/root/mnt/programs/user_data/plan_logger"
            stub = RemoteFileSystemServiceStub(self.channel)
            response = stub.list(FileRequest(name=[robot_plan_logger_dir]))
            # 成功获取文件夹时返回100000
            if response.rt.error_code != 100000:
                raise Exception(response.rt.error_message)
            latest_file = ""
            latest_mtime = 0
            # 查找满足filter且最新的文件
            for file in response.info:
                f_short_name = file.name.split("/")[-1]
                # 只读取以filter开头的文件
                if filter and not f_short_name.startswith(filter):
                    continue
                if file.mtime > latest_mtime:
                    latest_mtime = file.mtime
                    latest_file = file.name
            f_resp = stub.readStream(FileRequest(name=[latest_file]))
            return f_resp
        except grpc._channel._InactiveRpcError:
            logger.debug(
                f"{self.robot_ip}:{self.robot_grpc_port} grpc channel connection failed"
            )
        except Exception as e:
            logger.error(f"get robot ext axis error: {e}")
        return None
