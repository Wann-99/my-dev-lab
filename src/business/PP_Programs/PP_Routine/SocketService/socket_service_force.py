import socket
import threading
import csv
import os
from datetime import datetime
import time

# ================== 配置 ==================
HOST = "192.168.3.220"
PORT = 20000

GROUP_GAP_MS = 500          # 超过 500ms → 新组
CSV_FLUSH_INTERVAL = 20     # 每 N 条写一次 CSV

# ================== 文件名 ==================
def make_filename():
    return datetime.now().strftime("%Y-%m-%d-%H-%M-%S") + ".csv"

file_name = make_filename()

# ================== 全局数据 ==================
groups = []
current_group = None
lock = threading.Lock()

# ================== 新建一组 ==================
def start_new_group(reason=""):
    group_id = len(groups) + 1
    group = {
        "index": group_id,
        "time": [],
        "force_z": [],
        "pose_z": [],      # 新增 pose_z
        "counter": 0,
        "last_ts": None
    }
    groups.append(group)
    print(f"[INFO] >>> Start Group {group_id} {reason}")
    return group

# ================== CSV 写入 ==================
def flush_groups_to_csv(filename):
    if not groups:
        return

    max_rows = max(len(g["force_z"]) for g in groups)

    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)

        # 写表头
        header = []
        for g in groups:
            header += [f"第{g['index']}组", "时间", "Force_Z", "Pose_Z"]
        writer.writerow(header)

        # 写每行数据
        for i in range(max_rows):
            row = []
            for g in groups:
                if i < len(g["force_z"]):
                    row += [
                        g["index"],
                        g["time"][i],
                        g["force_z"][i],
                        g["pose_z"][i]
                    ]
                else:
                    row += ["", "", "", ""]
            writer.writerow(row)

# ================== 行解析 ==================
# 假设每行数据是 "force_z,pose_z"
def parse_line(line):
    parts = line.split(",")
    if len(parts) < 2:
        return None, None
    try:
        force_z = float(parts[0])
        pose_z = float(parts[1])
        return force_z, pose_z
    except ValueError:
        return None, None

# ================== 数据处理 ==================
def process_data(force_z, pose_z):
    global current_group

    now_ts = time.perf_counter()

    # 条件 1：第一条数据
    if current_group is None:
        current_group = start_new_group("[first data]")

    # 条件 2：时间间隔触发新组
    elif current_group["last_ts"] is not None:
        gap_ms = (now_ts - current_group["last_ts"]) * 1000
        if gap_ms > GROUP_GAP_MS:
            current_group = start_new_group(f"[gap {gap_ms:.2f} ms]")

    # 写入当前组
    current_group["time"].append(datetime.now().strftime("%H:%M:%S.%f")[:-3])
    current_group["force_z"].append(force_z)
    current_group["pose_z"].append(pose_z)
    current_group["last_ts"] = now_ts
    current_group["counter"] += 1

    if current_group["counter"] % CSV_FLUSH_INTERVAL == 0:
        flush_groups_to_csv(file_name)

# ================== TCP 线程 ==================
def tcp_worker(sock, addr):
    global current_group

    print(f"[INFO] Connection from {addr}")

    buffer = ""
    first_line = True

    try:
        while True:
            data = sock.recv(4096)
            if not data:
                # 断线 → 下一条数据必然新组
                with lock:
                    current_group = None
                    flush_groups_to_csv(file_name)
                break

            buffer += data.decode("utf-8", errors="ignore")

            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()

                if not line:
                    continue

                if first_line:
                    first_line = False
                    continue  # 跳过 Hi Flexiv
                # print(f"[RECV] Raw line: '{line}'")
                force_z, pose_z = parse_line(line)
                if force_z is None or pose_z is None:
                    continue

                with lock:
                    process_data(force_z, pose_z)

    except Exception as e:
        print("[ERROR]", e)
    finally:
        sock.close()
        print(f"[INFO] Connection closed {addr}")

# ================== 主程序 ==================
def main():
    if os.path.exists(file_name):
        os.remove(file_name)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    print(f"[INFO] Server listening on {HOST}:{PORT}")

    while True:
        sock, addr = server.accept()
        t = threading.Thread(
            target=tcp_worker,
            args=(sock, addr),
            daemon=True
        )
        t.start()

if __name__ == "__main__":
    main()
