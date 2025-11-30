import socket  # 导入socket模块，用于网络通信
import threading  # 导入threading模块，用于多线程处理
from datetime import datetime
import time

class TcpServer:
    def _get_time(self):
        t = datetime.now().timestamp()
        # t = time.time()
        return f"{time.strftime('%H:%M:%S')}.{int(t % 1 * 1000):06d}"


    def generate_response(self, message):
        """
        根据接收到的消息生成相应的响应内容。
        """
        # if message.lower() == '时间':
        #     current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        #     return f"当前服务器时间是: {current_time}"
        # if message.startswith('echo:'):
        #     # 返回冒号后面的内容
        #     return message[5:]
        if message.startswith("1"):
            json_string ='''{"name": "zhangsan"}'''
            # json_string = '''{"name": "张三","age": 30,"email": "zhangsan@example.com","skills": ["Python", "数据分析", "机器学习"]}'''
            return json_string
        elif message.startswith('reverse:'):
            # 返回反转后的字符串
            content = message[8:]
            return content[::-1]
        else:
            return f"服务器已收到: {message}"


    def handle_client(self, connection, client_address):
        # 打印客户端连接信息
        print(f"[{self._get_time()}] 连接来自 {client_address}")
        try:
            while True:
                # 接收数据
                data = connection.recv(1024)  # 从客户端接收最多1024字节的数据
                if data:
                    # print(f'[{self._get_time()}] 开始接收数据')
                    message = data.decode().strip()  # 解码并去除首尾空白字符
                    print(f"[{self._get_time()}] 收到来自{client_address}的数据: {message}")  # 打印接收到的消息

                    # 这里可以根据需要处理接收到的数据
                    response = self.generate_response(message)
                    # response = f"服务器已收到: {message}"  # 构建响应消息
                    print(f"[{self._get_time()}] 发送给{client_address}的数据: {response}")  # 打印要发送的消息
                    connection.sendall((response + '\n').encode('utf-8'))  # 将响应消息编码为UTF-8并发送给客户端
                    # print(f'[{self._get_time()}] 发送数据完成')
                else:
                    print(f"[{self._get_time()}] {client_address} 断开连接")  # 打印客户端断开连接的信息
                    break  # 退出循环
        except Exception as e:
            print(f"[{self._get_time()}] 与{client_address}通信时发生错误: {e}")  # 打印异常信息
        finally:
            connection.close()  # 关闭连接


    def start_server(self, host='192.168.2.220', port=30000):
        # 创建一个TCP/IP套接字
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # 设置端口复用
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # 绑定套接字到本地地址和端口
        server_address = (host, port)  # 定义服务器地址和端口
        # print(f"启动服务器在 {server_address}")  # 打印服务器启动信息
        print(f'[{self._get_time()}] Server started on {host}:{port}')
        self.server_socket.bind(server_address)  # 绑定套接字到指定地址和端口

        # 监听连接
        self.server_socket.listen(5)  # 开始监听连接，允许最多5个挂起连接
        print(f"[{self._get_time()}] 等待连接...")  # 打印等待连接信息

        try:
            while True:
                # 等待连接
                connection, client_address = self.server_socket.accept()  # 接受客户端连接
                # 为每个客户端连接创建一个新的线程
                client_thread = threading.Thread(target=self.handle_client, args=(connection, client_address))  # 创建新线程处理客户端连接
                client_thread.daemon = True  # 设置为守护线程，主线程退出时自动关闭
                client_thread.start()  # 启动线程
        except KeyboardInterrupt:
            print(f"[{self._get_time()}] 服务器正在关闭...")  # 捕获键盘中断信号，打印服务器关闭信息
        finally:
            self.server_socket.close()  # 关闭服务器套接字


if __name__ == "__main__":
    server = TcpServer()
    server.start_server()  # 启动服务器
