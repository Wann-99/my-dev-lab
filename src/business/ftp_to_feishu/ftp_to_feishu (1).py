import os
import ftplib
import datetime
import requests
import json
import re

# ================= 配置区域 =================
# FTP配置
FTP_HOST = "192.168.3.102"
FTP_PORT = 21
FTP_USER = "qnxuser"
FTP_PASS = "qnxuser"
FTP_DIR = "/programs/log"

# 飞书机器人配置
# 在飞书群设置 -> 机器人 -> 添加自定义机器人，获取 Webhook 地址
FEISHU_WEBHOOK_URL = "https://open.feishu.cn/open-apis/bot/v2/hook/8b0485cb-c057-4463-afd1-2f92626e8c39"


# 日志命名规则: RobotControlApp_2026-04-27_09-48-56.1.log
LOG_PREFIX = "RobotControlApp_"
# ==========================================

def download_target_logs():
    """从FTP下载当天或最近一天的日志文件"""
    downloaded_files = []
    target_date_str = None
    
    print(f"正在连接FTP服务器: {FTP_HOST}...")
    try:
        ftp = ftplib.FTP()
        ftp.connect(FTP_HOST, FTP_PORT)
        ftp.login(FTP_USER, FTP_PASS)
        ftp.cwd(FTP_DIR)
        
        print("正在获取FTP目录下的日志文件列表...")
        # 获取目录下所有文件
        files = ftp.nlst()
        
        # 使用正则提取所有日志文件中的日期 (YYYY-MM-DD)
        date_pattern = re.compile(rf"{LOG_PREFIX}(\d{{4}}-\d{{2}}-\d{{2}})")
        available_dates = set()
        
        for f in files:
            if f.endswith(".log"):
                match = date_pattern.search(f)
                if match:
                    available_dates.add(match.group(1))
                    
        if not available_dates:
            print("FTP目录下未找到任何符合格式的日志文件。")
            ftp.quit()
            return downloaded_files, target_date_str
            
        # 对找到的日期进行降序排序
        sorted_dates = sorted(list(available_dates), reverse=True)
        today_str = datetime.datetime.now().strftime("%Y-%m-%d")
        
        if today_str in sorted_dates:
            target_date_str = today_str
            print(f"找到当天的日志，准备下载: {target_date_str}")
        else:
            target_date_str = sorted_dates[0]
            print(f"未找到当天的日志，将使用最近的日志日期: {target_date_str}")
            
        file_pattern = f"{LOG_PREFIX}{target_date_str}"
        target_files = [f for f in files if file_pattern in f and f.endswith(".log")]
        
        for filename in target_files:
            local_filepath = os.path.join(os.getcwd(), filename)
            print(f"正在下载: {filename}...")
            with open(local_filepath, 'wb') as f:
                ftp.retrbinary(f'RETR {filename}', f.write)
            downloaded_files.append(local_filepath)
            
        ftp.quit()
        print(f"下载完成，共下载 {len(downloaded_files)} 个文件。")
        return downloaded_files, target_date_str
    except Exception as e:
        print(f"FTP操作失败: {e}")
        return downloaded_files, target_date_str

def parse_cycle_time(filepaths):
    """解析日志文件中的节拍(Cycle Time)数据"""
    if not filepaths:
        return None

    # 存储各个Plan的节拍数据: { "PlanName": [time1, time2, ...] }
    plan_times = {}
    
    plan_pattern = re.compile(r'====== Plan \[([^\]]+)\] Time Log =====')
    time_pattern = re.compile(r'Total Time\s*=\s*([0-9.]+)\s*\[s\]')
    
    for filepath in filepaths:
        if not os.path.exists(filepath):
            continue
            
        print(f"正在解析: {os.path.basename(filepath)}...")
        current_plan = None
        try:
            # 考虑到日志可能包含非UTF-8字符，使用 errors='ignore'
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    plan_match = plan_pattern.search(line)
                    if plan_match:
                        current_plan = plan_match.group(1)
                        continue
                    
                    time_match = time_pattern.search(line)
                    if time_match and current_plan:
                        t = float(time_match.group(1))
                        if current_plan not in plan_times:
                            plan_times[current_plan] = []
                        plan_times[current_plan].append(t)
                        current_plan = None  # 重置，等待下一个Plan
        except Exception as e:
            print(f"解析 {filepath} 时发生错误: {e}")
            
    # 计算统计信息
    stats = []
    for plan, times in plan_times.items():
        if times:
            avg_time = sum(times) / len(times)
            min_time = min(times)
            max_time = max(times)
            total_time = sum(times)
            stats.append({
                "plan": plan,
                "count": len(times),
                "avg": avg_time,
                "min": min_time,
                "max": max_time,
                "total": total_time
            })
            
    # 按平均节拍时间降序排序
    stats.sort(key=lambda x: x["avg"], reverse=True)
    return stats

def send_to_feishu(stats_data, target_date_str):
    """将节拍统计数据发送到飞书"""
    if not stats_data:
        print("没有节拍数据可发送。")
        return

    # 如果无法获取日期（比如本地测试回退情况），使用当天日期
    if not target_date_str:
        target_date_str = datetime.datetime.now().strftime("%Y-%m-%d")
    
    content = [
        [{"tag": "text", "text": f"📅 日志日期: {target_date_str}\n\n"}]
    ]
    
    content.append([{"tag": "text", "text": "⏱️ 各任务节点节拍统计 (按平均耗时降序):\n"}])
    
    for item in stats_data:
        # 格式化每行文本
        line_text = (
            f"🔹 [{item['plan']}]\n"
            f"   执行次数: {item['count']} 次\n"
            f"   平均节拍: {item['avg']:.3f} s (最小: {item['min']:.3f} s, 最大: {item['max']:.3f} s)\n"
        )
        content.append([{"tag": "text", "text": line_text}])

    payload = {
        "msg_type": "post",
        "content": {
            "post": {
                "zh_cn": {
                    "title": "📊 机器人运行节拍报告",
                    "content": content
                }
            }
        }
    }

    headers = {'Content-Type': 'application/json'}

    print("正在发送报告到飞书...")
    try:
        response = requests.post(FEISHU_WEBHOOK_URL, headers=headers, data=json.dumps(payload))
        if response.status_code == 200:
            print("飞书消息发送成功！")
        else:
            print(f"飞书消息发送失败，状态码: {response.status_code}, 响应: {response.text}")
    except Exception as e:
        print(f"发送请求到飞书时发生异常: {e}")

def main():
    print("=== 开始执行机器人节拍统计自动化任务 ===")
    
    # 1. 批量下载日志文件 (优先当天，没有则取最近日期)
    downloaded_files, target_date_str = download_target_logs()
    
    # 测试代码：如果在本地调试且没有配置真实FTP，可以直接使用当前目录下的日志文件
    if not downloaded_files:
        print("尝试在本地目录查找符合条件的日志...")
        today_str = datetime.datetime.now().strftime("%Y-%m-%d")
        file_pattern = f"{LOG_PREFIX}{today_str}"
        for f in os.listdir(os.getcwd()):
            if file_pattern in f and f.endswith(".log"):
                downloaded_files.append(os.path.join(os.getcwd(), f))
        if downloaded_files:
            target_date_str = today_str
    
    # 2. 解析日志提取节拍数据
    if downloaded_files:
        stats_data = parse_cycle_time(downloaded_files)
        
        # 3. 发送到飞书
        if stats_data:
            send_to_feishu(stats_data, target_date_str)
        else:
            print("未在日志中解析到有效的节拍数据。")
    else:
        print("没有可处理的日志文件。")
            
    print("=== 自动化任务执行结束 ===")

if __name__ == "__main__":
    main()
