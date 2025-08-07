import socket
import threading
import time  # 新增时间模块

class TcpServer:
    def __init__(self, host='192.168.100.205', port=20000):
        # 初始化服务器参数
        self.host = host      # 服务器监听IP地址
        self.port = port      # 服务器监听端口
        self.server_socket = None  # 服务器Socket对象
        self.running = False       # 服务器运行状态标志
        # self.log_file = log_file  # 新增日志文件路径
        # self.lock = threading.Lock()  # 新增线程锁

    # def _log(self, message):
    #     """统一的日志记录方法（线程安全）"""
    #     log_entry = f"[{self._get_time()}] {message}"
    #
    #     # 控制台输出
    #     print(log_entry)
    #
    #     # 文件写入（线程安全）
    #     with self.lock:
    #         with open(self.log_file, 'a', encoding='utf-8') as f:
    #             f.write(log_entry + '\n')

    def _get_time(self):
        t = time.time()
        return f"{time.strftime('%H:%M:%S')}.{int(t % 1 * 1000):04d}"

    def start(self):
        """启动TCP服务器"""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # 设置端口复用

        try:
            self.server_socket.bind((self.host, self.port))  # 绑定地址和端口
            self.server_socket.listen(5)  # 开始监听，最大排队连接数5
            print('Wait for connection...')
            # 添加时间戳的启动日志
            print(f'[{self._get_time()}] Server started on {self.host}:{self.port}')
            self.running = True

            # 主循环接受连接
            while self.running:
                client_sock, addr = self.server_socket.accept()  # 阻塞等待客户端连接
                # 带时间的连接接受日志
                print(f'[{self._get_time()}] Accepted connection from {addr}')
                # 为每个客户端创建新线程
                threading.Thread(
                    target=self.handle_client,
                    args=(client_sock, addr),
                    daemon=True  # 设置为守护线程
                ).start()

        except Exception as e:
            print(f"[{self._get_time()}] Server error: {e}")
        finally:
            self.stop()

    def handle_client(self, client_socket, client_address):
        """处理客户端连接的线程函数"""
        try:
            while self.running:
                data = client_socket.recv(1024)  # 接收数据（最大1024字节）
                if not data:  # 客户端断开连接时跳出循环
                    break

                # 处理接收到的数据（添加时间戳）
                decoded_data = data.decode('utf-8').strip()
                print(f'[{self._get_time()}] Received from {client_address}: {decoded_data}')

        except Exception as e:
            print(f'[{self._get_time()}] Error handling client {client_address}: {e}')
        finally:
            client_socket.close()  # 关闭客户端连接
            print(f'[{self._get_time()}] Closed connection from {client_address}')

    def stop(self):
        """关闭服务器"""
        self.running = False
        if self.server_socket:
            self.server_socket.close()  # 关闭服务器Socket
        print(f"[{self._get_time()}] Server stopped")  # 修正拼写并添加时间戳


if __name__ == "__main__":
    server = TcpServer()  # 创建服务器实例
    server.start()        # 启动服务器
