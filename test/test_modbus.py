import time
import csv
import logging
import statistics
from collections import defaultdict
from pymodbus.client import ModbusTcpClient

# ================= 日志 =================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

# ================= 配置 =================
TCP_HOST = "192.168.2.100"
TCP_PORT = 502

CYCLE_COUNT = 50
REGISTER_COUNT = 5
DELAY_BETWEEN_CYCLES = 0.05

COIL_START = 0
DISCRETE_INPUT_START = 0
HOLDING_REGISTER_START = 0
INPUT_REGISTER_START = 0

DETAIL_CSV = "modbus_detail_log.csv"
REPORT_CSV = "modbus_performance_report.csv"

# ================= 数据容器 =================
latency_data = defaultdict(list)
result_count = defaultdict(lambda: {"ok": 0, "fail": 0})

# ================= CSV 初始化 =================
with open(DETAIL_CSV, "w", newline="") as f:
    csv.writer(f).writerow([
        "Cycle", "RegisterType", "Operation",
        "Latency(ms)", "Status"
    ])

def log_detail(cycle, rtype, op, latency, status):
    with open(DETAIL_CSV, "a", newline="") as f:
        csv.writer(f).writerow([
            cycle, rtype, op, f"{latency:.2f}", status
        ])

    key = f"{rtype}-{op}"
    if status == "OK":
        latency_data[key].append(latency)
        result_count[key]["ok"] += 1
    else:
        result_count[key]["fail"] += 1

# ================= 连接 =================
client = ModbusTcpClient(TCP_HOST, port=TCP_PORT)
if not client.connect():
    log.error("❌ 无法连接 Modbus TCP")
    exit(1)

log.info(f"✅ 已连接 Modbus TCP {TCP_HOST}:{TCP_PORT}")

# ================= 测试函数 =================
def measure(cycle, rtype, op, func):
    t0 = time.perf_counter()
    resp = func()
    latency = (time.perf_counter() - t0) * 1000
    status = "OK" if resp and not resp.isError() else "FAIL"
    log_detail(cycle, rtype, op, latency, status)

def test_cycle(cycle):
    measure(cycle, "Coils", "Write",
            lambda: client.write_coils(
                COIL_START, [True, False] * (REGISTER_COUNT // 2 + 1)
            ))

    measure(cycle, "Coils", "Read",
            lambda: client.read_coils(
                COIL_START, count=REGISTER_COUNT
            ))

    measure(cycle, "DiscreteInputs", "Read",
            lambda: client.read_discrete_inputs(
                DISCRETE_INPUT_START, count=REGISTER_COUNT
            ))

    measure(cycle, "HoldingRegisters", "Write",
            lambda: client.write_registers(
                HOLDING_REGISTER_START, list(range(REGISTER_COUNT))
            ))

    measure(cycle, "HoldingRegisters", "Read",
            lambda: client.read_holding_registers(
                HOLDING_REGISTER_START, count=REGISTER_COUNT
            ))

    measure(cycle, "InputRegisters", "Read",
            lambda: client.read_input_registers(
                INPUT_REGISTER_START, count=REGISTER_COUNT
            ))

# ================= 主循环 =================
log.info(f"🚀 开始压力测试：{CYCLE_COUNT} 轮")

start = time.time()
for c in range(1, CYCLE_COUNT + 1):
    log.info(f"Cycle {c}/{CYCLE_COUNT}")
    test_cycle(c)
    time.sleep(DELAY_BETWEEN_CYCLES)

log.info(f"✅ 测试完成，用时 {time.time() - start:.2f}s")

client.close()

# ================= 生成性能报告 =================
with open(REPORT_CSV, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "RegisterType-Operation",
        "Requests",
        "Success",
        "Fail",
        "SuccessRate(%)",
        "Avg(ms)",
        "Max(ms)",
        "P95(ms)"
    ])

    for key, times in latency_data.items():
        ok = result_count[key]["ok"]
        fail = result_count[key]["fail"]
        total = ok + fail

        avg = statistics.mean(times)
        max_v = max(times)
        p95 = statistics.quantiles(times, n=100)[94]

        writer.writerow([
            key,
            total,
            ok,
            fail,
            f"{ok / total * 100:.2f}",
            f"{avg:.2f}",
            f"{max_v:.2f}",
            f"{p95:.2f}"
        ])

log.info(f"📊 性能报告已生成：{REPORT_CSV}")
log.info(f"📄 明细日志：{DETAIL_CSV}")
