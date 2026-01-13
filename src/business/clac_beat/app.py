import os
import signal
import sys
import webbrowser
import logging
from flask import Flask, request, jsonify, send_from_directory, render_template
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
import plotly.io as pio
from werkzeug.utils import secure_filename
import re
import tempfile
import uuid
from datetime import datetime
import threading
import urllib.request
import time
import socket  # 新增


# --- 1. 路径修复 (适配 PyInstaller) ---
def get_resource_path(relative_path):
    """ 获取资源绝对路径 (兼容 Dev 和 PyInstaller) """
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), relative_path)


logging.basicConfig(
    level=logging.WARNING,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# --- Flask 配置 ---
# 显式指定绝对路径，防止打包后 404
template_folder = get_resource_path("templates")
static_folder = get_resource_path("static")

# 注意：static_url_path 保持默认 '/static' 即可，只要 folder 对了就行
app = Flask(__name__, template_folder=template_folder, static_folder=static_folder)

# Optional: Enable CORS
try:
    from flask_cors import CORS

    CORS(app)
except Exception as e:
    logger.warning(f"CORS not available: {e}")

# File upload directory (保持在用户运行目录下，而不是临时目录，方便查看)
# 如果希望打包后也能读写，建议用 os.getcwd() 或者 user home
# 这里保持原样，但在打包 exe 后，dirname(__file__) 可能会是临时目录
# 建议改为: os.getcwd()
UPLOAD_FOLDER = os.path.join(os.getcwd(), "result")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


# ... (中间的 validate_file_structure, name_has_datetime, process_node_group, analyze_csv, generate_charts 函数保持不变) ...
# 为了节省篇幅，这里省略这部分业务逻辑代码，请直接保留你原来的函数实现即可
# ... (业务逻辑结束) ...

# 这里简单占位，请把你原来的业务函数 validate_file_structure 到 generate_charts 完整贴在这里
# ================= 业务逻辑区域 =================
# (请保留你原代码中的: validate_file_structure, name_has_datetime, process_node_group, analyze_csv, generate_charts)
# ===============================================

# 为了代码能跑，我把原来的函数引用过来 (实际使用时请确保这些函数在文件里)
def validate_file_structure(df):
    required_cols = {"NodeTime", "NodePath", "ProgramTime", "PlanTime"}
    missing_cols = required_cols - set(df.columns)
    if missing_cols: raise ValueError(f"CSV missing columns: {missing_cols}")
    if df.empty: raise ValueError("CSV file is empty")


def name_has_datetime(s: str) -> bool: return False  # 简略


# ... 其他函数请保留 ...

# --- 路由部分 ---
@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")


# 静态文件路由通常 Flask 会自动处理，但为了保险保留你的写法
@app.route('/static/css/<path:filename>')
def css_files(filename):
    return send_from_directory(os.path.join(static_folder, 'css'), filename)


@app.route('/static/js/<path:filename>')
def js_files(filename):
    return send_from_directory(os.path.join(static_folder, 'js'), filename)


@app.route("/favicon.ico")
def favicon():
    return send_from_directory(static_folder, 'favicon.ico')


# --- 2. 退出逻辑 (供前端 AJAX 调用) ---
@app.route('/shutdown', methods=['GET', 'POST'])
def shutdown():
    """接收退出信号，延迟自杀"""

    def _exit():
        time.sleep(0.5)
        logger.warning("Force exiting via shutdown route...")
        os._exit(0)  # 强制退出进程

    # 启动一个守护线程去执行退出，立刻返回响应给前端
    threading.Thread(target=_exit, daemon=True).start()
    return jsonify({"status": "shutting down"})


@app.route("/api/analyze", methods=["POST"])
def api_analyze():
    # ... (保留你的 api_analyze 代码) ...
    # 这里省略具体实现，与原代码一致
    return jsonify({"error": "Please replace this with your original logic"})


@app.route("/download/<path:filename>", methods=["GET"])
def download_file(filename):
    try:
        return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=True)
    except Exception as e:
        logger.error(f"File download failed: {e}")
        return jsonify({"error": "File download failed"}), 500


# --- 3. 寻找空闲端口 ---
def get_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        return s.getsockname()[1]


# --- 4. 启动逻辑 ---
def start_app():
    # 动态端口 (或固定 5000)
    port = 5000

    def _start_server():
        # use_reloader=False 很重要，否则 pywebview 会启动两次
        app.run(host="127.0.0.1", port=port, debug=False, use_reloader=False)

    try:
        import webview
        # 启动 Flask 线程 (Daemon)
        t = threading.Thread(target=_start_server, daemon=True)
        t.start()

        # 等待一小会儿确保 Flask 启动
        time.sleep(0.5)

        # 创建窗口
        window = webview.create_window(
            'Robot Beat Analysis',
            f'http://127.0.0.1:{port}/',
            width=1200, height=800,
            resizable=True
        )

        # 定义窗口关闭时的回调
        def _on_closed():
            print("Webview window closed. Cleaning up...")
            # 1. 尝试通知 Flask 退出 (礼貌性)
            try:
                urllib.request.urlopen(f'http://127.0.0.1:{port}/shutdown', timeout=1)
            except Exception:
                pass

            # 2. 无论如何，强制自杀 (关键!)
            # 稍微延迟一点点，防止请求没发出去
            time.sleep(0.2)
            os._exit(0)

        window.events.closed += _on_closed
        webview.start()

    except ImportError:
        # 如果没有安装 pywebview，回退到浏览器模式
        logger.warning("pywebview not installed. Falling back to browser.")
        url = f"http://127.0.0.1:{port}/"
        threading.Thread(target=lambda: (time.sleep(1), webbrowser.open(url)), daemon=True).start()
        app.run(host="127.0.0.1", port=port, debug=False)


if __name__ == "__main__":
    # 在 Windows 上，multiprocessing 需要 freeze_support
    # 虽然 Flask 主要用 threading，但加一行保险
    if sys.platform.startswith('win'):
        import multiprocessing

        multiprocessing.freeze_support()

    start_app()