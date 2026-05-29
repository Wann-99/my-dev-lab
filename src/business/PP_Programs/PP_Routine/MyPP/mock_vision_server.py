import socket
import time
import random


def start_mock_vision_server(host='192.168.2.50', port=30000):
    """
    启动一个模拟的视觉服务器 (TCP Server)，用于接收机器人的 Trigger 信号，
    并返回模拟的位姿数据。
    """
    print(f"[*] 正在启动模拟视觉服务器 {host}:{port} ...")

    # 创建 TCP Socket
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # 允许端口复用
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        # 绑定地址和端口
        server_socket.bind((host, port))
        # 开始监听，最大连接数为 1
        server_socket.listen(1)
        print("[*] 服务器启动成功，等待机器人连接...")

        while True:
            # 阻塞等待客户端(机器人)连接
            client_socket, client_address = server_socket.accept()
            print(f"[+] 机器人已连接: {client_address}")

            try:
                while True:
                    # 接收机器人的数据
                    data = client_socket.recv(1024)

                    # 如果数据为空，说明客户端已断开连接
                    if not data:
                        print("[-] 机器人断开连接")
                        break

                    recv_str = data.decode('utf-8').strip()
                    print(f"[<] 收到数据: {recv_str}")

                    # 判断是否收到 Trigger 信号
                    if 'Trigger' in recv_str:
                        # 模拟生成物体位姿数据 (x, y, z, rx, ry, rz)
                        # 为了测试工作空间逻辑，我们随机生成一些数据
                        x = round(random.uniform(0.06, 0.25), 4)
                        y = round(random.uniform(0, 0.3), 4)
                        z = round(random.uniform(-0.9, -0.6), 4)
                        rx = 0
                        ry = 0
                        rz = 0

                        # 构造和机器人 PP 代码解析格式一致的字符串
                        # 格式: x y z rx ry rz (xyz单位为m, rxryrz表示ZYX欧拉角单位为deg)
                        # 【重要修改】：在末尾增加 \n 换行符，很多机器人的 socket_recv 依赖换行符来判断单次数据包结束
                        response_str = f"{x} {y} {z} {rx} {ry} {rz}\n"

                        # 发送回机器人
                        client_socket.sendall(response_str.encode('utf-8'))
                        print(f"[>] 发送数据: {response_str}")

                    else:
                        print(f"[!] 收到未知指令: {recv_str}")

            except ConnectionResetError:
                print("[-] 机器人异常断开连接")
            except Exception as e:
                print(f"[x] 通信发生错误: {e}")
            finally:
                client_socket.close()
                print("[*] 重新等待机器人连接...\n")

    except Exception as e:
        print(f"[x] 服务器启动失败: {e}")
    finally:
        server_socket.close()


if __name__ == '__main__':
    # 监听 '0.0.0.0' 表示允许来自任何网络接口的外部设备（如机器人）连接到本机
    # 机器人端的 PP 程序中，socket_open 的 IP 必须填 "你的电脑在局域网中的IP地址" (例如 192.168.2.10)
    start_mock_vision_server(host='192.168.3.220', port=30000)
