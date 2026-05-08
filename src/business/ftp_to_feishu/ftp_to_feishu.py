import os
import ftplib
import datetime
import requests
import json
import re
import csv

def load_config(config_path="config.json"):
    """从单独的 JSON 文件加载配置"""
    if not os.path.exists(config_path):
        print(f"配置文件 {config_path} 不存在！请创建。")
        return None
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"读取配置文件失败: {e}")
        return None

def download_target_logs(ftp_config):
    """从FTP下载当天或最近一天的日志文件"""
    downloaded_files = []
    target_date_str = None
    
    host = ftp_config.get("host")
    port = ftp_config.get("port", 21)
    user = ftp_config.get("user")
    password = ftp_config.get("password")
    directory = ftp_config.get("directory")
    log_prefix = ftp_config.get("log_prefix")
    
    print(f"正在连接FTP服务器: {host}...")
    try:
        ftp = ftplib.FTP()
        ftp.connect(host, port)
        ftp.login(user, password)
        ftp.cwd(directory)
        
        print("正在获取FTP目录下的日志文件列表...")
        # 获取目录下所有文件
        files = ftp.nlst()
        
        # 使用正则提取所有日志文件中的日期 (YYYY-MM-DD)
        date_pattern = re.compile(rf"{log_prefix}(\d{{4}}-\d{{2}}-\d{{2}})")
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
            
        file_pattern = f"{log_prefix}{target_date_str}"
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

def parse_target_plan(filepaths, target_plan, trigger_node):
    """解析指定 Plan 中的循环体耗时"""
    if not filepaths:
        return None

    runs = []
    
    plan_start_pattern = re.compile(rf'====== Plan \[{re.escape(target_plan)}\] Time Log =====')
    node_pattern = re.compile(r'node \[([^\]]+)\] time : ([0-9.]+) \[s\]')
    total_time_pattern = re.compile(r'Total Time\s*=\s*([0-9.]+)\s*\[s\]')
    plan_end_pattern = re.compile(r'==================================================')
    
    for filepath in filepaths:
        if not os.path.exists(filepath):
            continue
            
        print(f"正在解析: {os.path.basename(filepath)}...")
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            in_target_plan = False
            current_run = None
            current_cycle = None
            
            for line in f:
                if not in_target_plan:
                    if plan_start_pattern.search(line):
                        in_target_plan = True
                        current_run = {
                            "init_nodes": [],
                            "cycles": [],
                            "total_time": 0
                        }
                        current_cycle = None
                    continue
                
                # 正在解析目标 Plan 块内部
                node_match = node_pattern.search(line)
                if node_match:
                    node_name = node_match.group(1)
                    node_time = float(node_match.group(2))
                    
                    if node_name == trigger_node:
                        # 遇到触发节点，保存上一个循环体
                        if current_cycle is not None:
                            current_run["cycles"].append(current_cycle)
                        # 开启新的循环体
                        current_cycle = [{"node": node_name, "time": node_time}]
                    else:
                        if current_cycle is None:
                            # 还没遇到触发节点，属于初始化阶段
                            current_run["init_nodes"].append({"node": node_name, "time": node_time})
                        else:
                            # 添加到当前循环体中
                            current_cycle.append({"node": node_name, "time": node_time})
                else:
                    time_match = total_time_pattern.search(line)
                    if time_match:
                        current_run["total_time"] = float(time_match.group(1))
                        # 块结束，保存最后一个循环体
                        if current_cycle is not None:
                            current_run["cycles"].append(current_cycle)
                            current_cycle = None
                            
                    elif plan_end_pattern.search(line) or line.startswith("======"):
                        # 当前块彻底结束
                        if current_run and current_run["total_time"] > 0:
                            runs.append(current_run)
                        in_target_plan = False
                        current_run = None
                        current_cycle = None
                        
                        # 检查是否紧接着开始了另一个同样的Plan
                        if plan_start_pattern.search(line):
                            in_target_plan = True
                            current_run = {
                                "init_nodes": [],
                                "cycles": [],
                                "total_time": 0
                            }
                            current_cycle = None

    if not runs:
        return None
        
    # 按照运行顺序为每个 run 添加详细的统计数据
    detailed_runs = []
    for i, r in enumerate(runs, 1):
        run_data = {
            "index": i,
            "total_time": r["total_time"],
            "cycles_count": 0,
            "avg_cycle": "-",
            "max_cycle": "-",
            "min_cycle": "-",
            "init_nodes": r["init_nodes"],
            "cycles_detail": []
        }
        
        # 过滤有效循环体
        valid_cycles = [c for c in r["cycles"] if len(c) > 1]
        
        if valid_cycles:
            cycle_times = [sum(n["time"] for n in c) for c in valid_cycles]
            run_data["cycles_count"] = len(valid_cycles)
            run_data["avg_cycle"] = f"{sum(cycle_times)/len(cycle_times):.3f}s"
            run_data["max_cycle"] = f"{max(cycle_times):.3f}s"
            run_data["min_cycle"] = f"{min(cycle_times):.3f}s"
            
            # 保存每次循环的耗时和内部节点详细时间
            for idx, c in enumerate(valid_cycles, 1):
                c_time = sum(n["time"] for n in c)
                # 提取子节点耗时，格式化为: NodeName(0.000s)
                sub_nodes_str = ", ".join([f"{n['node']}({n['time']:.3f})" for n in c])
                run_data["cycles_detail"].append({
                    "cycle_index": idx,
                    "cycle_total_time": c_time,
                    "sub_nodes_str": sub_nodes_str
                })
            
        detailed_runs.append(run_data)
    
    # 全局汇总数据（用于总览）
    total_runs = len(runs)
    total_time_all_runs = sum(r["total_time"] for r in runs)
    
    return {
        "target_plan": target_plan,
        "trigger_node": trigger_node,
        "runs_count": total_runs,
        "total_time_sum": total_time_all_runs,
        "detailed_runs": detailed_runs
    }

def send_to_feishu(stats, target_date_str, feishu_config):
    """将节拍统计数据发送到飞书"""
    if not stats:
        print("没有节拍数据可发送。")
        return
        
    webhook_url = feishu_config.get("webhook_url")
    if not webhook_url:
        print("未配置飞书 Webhook URL")
        return

    # 如果无法获取日期（比如本地测试回退情况），使用当天日期
    if not target_date_str:
        target_date_str = datetime.datetime.now().strftime("%Y-%m-%d")
        
    plan_name = stats["target_plan"]
    
    content = [
        [{"tag": "text", "text": f"🤖 关键字验证: 节拍报告\n"}],
        [{"tag": "text", "text": f"📅 日志日期: {target_date_str}\n"}],
        [{"tag": "text", "text": f"🚀 目标任务: {plan_name}\n"}],
        [{"tag": "text", "text": f"📊 运行次数: {stats['runs_count']} 次 (总耗时: {stats['total_time_sum']:.3f}s)\n\n"}]
    ]
    
    # 遍历输出各次运行的详细信息
    for run in stats['detailed_runs']:
        content.append([{"tag": "text", "text": "----------------------------------------\n"}])
        content.append([{"tag": "text", "text": f"📋 运行记录 #{run['index']}\n"}])
        content.append([{"tag": "text", "text": f"总耗时: {run['total_time']:.3f}s | 循环体: {run['cycles_count']} 个\n"}])
        if run['cycles_count'] > 0:
            content.append([{"tag": "text", "text": f"循环均值: {run['avg_cycle']} | 最大: {run['max_cycle']} | 最小: {run['min_cycle']}\n\n"}])
        
        # 打印该次运行的初始化节点
        if run['init_nodes']:
            init_str = ", ".join([f"{n['node']}({n['time']:.3f})" for n in run['init_nodes']])
            content.append([{"tag": "text", "text": f"🚀 初始化:\n   {init_str}\n\n"}])
            
        # 打印该次运行中每一个循环的耗时明细
        if run['cycles_detail']:
            for cycle in run['cycles_detail']:
                content.append([{"tag": "text", "text": f"🔄 循环 #{cycle['cycle_index']} (总耗时 {cycle['cycle_total_time']:.3f}s):\n"}])
                content.append([{"tag": "text", "text": f"   {cycle['sub_nodes_str']}\n"}])
            content.append([{"tag": "text", "text": "\n"}])
            
    def send_chunk(content_chunk, is_first_chunk, total_chunks, chunk_index):
        if not is_first_chunk:
            # 对于后续分块，由于关键字可能只在第一块生效（如果您开了自定义关键字检查）
            # 我们在每块开头都补充上这个关键字，确保能被发送出去
            content_chunk = [[{"tag": "text", "text": f"🤖 关键字验证: 节拍报告\n"}]] + content_chunk
            
        payload = {
            "msg_type": "post",
            "content": {
                "post": {
                    "zh_cn": {
                        "title": f"节拍报告 📈 [{plan_name}] 分析 ({chunk_index}/{total_chunks})" if total_chunks > 1 else f"节拍报告 📈 [{plan_name}] 分析",
                        "content": content_chunk
                    }
                }
            }
        }
        
        try:
            response = requests.post(webhook_url, headers={'Content-Type': 'application/json'}, data=json.dumps(payload))
            resp_json = response.json()
            if response.status_code == 200 and resp_json.get("code") == 0:
                print(f"飞书消息发送成功 (片段 {chunk_index}/{total_chunks})！")
            else:
                print(f"飞书消息发送失败 (片段 {chunk_index}/{total_chunks})！")
                print(f"HTTP状态码: {response.status_code}")
                print(f"详细响应: {response.text}")
        except Exception as e:
            print(f"发送请求到飞书时发生异常: {e}")

    # 将内容分块以防止超过飞书 30KB 的限制
    # 这里通过限制每个请求中的文本块数量来控制大小
    MAX_ELEMENTS_PER_CHUNK = 80
    current_chunk = []
    chunks = []
    
    for item in content:
        current_chunk.append(item)
        if len(current_chunk) >= MAX_ELEMENTS_PER_CHUNK:
            chunks.append(current_chunk)
            current_chunk = []
            
    if current_chunk:
        chunks.append(current_chunk)
        
    print(f"正在发送报告到飞书... (总共分为 {len(chunks)} 条消息)")
    for idx, chunk in enumerate(chunks, 1):
        send_chunk(chunk, idx == 1, len(chunks), idx)

def main():
    print("=== 开始执行机器人节拍统计自动化任务 ===")
    
    config = load_config()
    if not config:
        return
        
    ftp_config = config.get("ftp", {})
    feishu_config = config.get("feishu", {})
    parser_config = config.get("parser", {})
    
    target_plan_name = parser_config.get("target_plan_name")
    loop_trigger_node = parser_config.get("loop_trigger_node")
    log_prefix = ftp_config.get("log_prefix")
    
    # 1. 批量下载日志文件 (优先当天，没有则取最近日期)
    downloaded_files, target_date_str = download_target_logs(ftp_config)
    
    # 测试代码：如果在本地调试且没有配置真实FTP，可以直接使用当前目录下的日志文件
    if not downloaded_files:
        print("尝试在本地目录查找符合条件的日志...")
        today_str = datetime.datetime.now().strftime("%Y-%m-%d")
        file_pattern = f"{log_prefix}{today_str}"
        for f in os.listdir(os.getcwd()):
            if file_pattern in f and f.endswith(".log"):
                downloaded_files.append(os.path.join(os.getcwd(), f))
        if downloaded_files:
            target_date_str = today_str
    
    # 2. 解析日志提取节拍数据
    if downloaded_files:
        stats_data = parse_target_plan(downloaded_files, target_plan_name, loop_trigger_node)
        
        # 3. 发送到飞书
        if stats_data:
            send_to_feishu(stats_data, target_date_str, feishu_config)
        else:
            print(f"未在日志中解析到有效的节拍数据 (目标 Plan: {target_plan_name}).")
    else:
        print("没有可处理的日志文件。")
            
    print("=== 自动化任务执行结束 ===")

if __name__ == "__main__":
    main()
