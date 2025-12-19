import os
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

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 尝试导入CORS
try:
    from flask_cors import CORS
    CORS_AVAILABLE = True
except ImportError:
    logger.warning("flask_cors is not installed. CORS will be disabled.")
    CORS_AVAILABLE = False

# 初始化Flask应用
app = Flask(__name__, template_folder="templates", static_folder="static", static_url_path="/static")
if CORS_AVAILABLE:
    CORS(app)

# 配置上传文件夹
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', os.path.join(os.path.dirname(__file__), "result"))
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

ALLOWED_EXTENSIONS = {'csv'}

def allowed_file(filename):
    """检查文件扩展名是否允许"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def validate_file_structure(df):
    """验证CSV文件的结构"""
    required_cols = {"NodeTime", "NodePath", "ProgramTime", "PlanTime"}
    missing_cols = required_cols - set(df.columns)
    if missing_cols:
        raise ValueError(f"CSV缺少以下列: {missing_cols}")
    if df.empty:
        raise ValueError("CSV文件为空")

def name_has_datetime(s: str) -> bool:
    """检查文件名是否包含日期时间"""
    patterns = [
        r'(?:^|[^0-9])(19|20)\d{2}[-_/.]?(0[1-9]|1[0-2])[-_/.]?(0[1-9]|[12]\d|3[01])(?:[^0-9]|$)',
        r'(?:^|[^0-9])(0[1-9]|[12]\d|3[01])[-_/.]?(0[1-9]|1[0-2])[-_/.]?(19|20)\d{2}(?:[^0-9]|$)',
        r'(?:^|[^0-9])(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?:[^0-9]|$)'
    ]
    time_patterns = [
        r'(?:^|[^0-9])([01]\d|2[0-3])([0-5]\d)([0-5]\d)(?:[^0-9]|$)',
        r'(?:^|[^0-9])([01]\d|2[0-3])[-_:]([0-5]\d)(?:[-_:]([0-5]\d))?(?:[^0-9]|$)'
    ]
    for rgx in patterns + time_patterns:
        if re.search(rgx, s):
            return True
    return False

# -------------------------------------------------------------------------
# 核心逻辑：process_node_group
# -------------------------------------------------------------------------
def process_node_group(group):
    """
    处理每个节点组，计算循环时间和标识周期。
    规则更新：
    1. 动态计算采样周期：基于ProgramTime的中位数差值
    2. 多行数据：CycleTime = Max - Min
    3. 单行数据：CycleTime = 动态计算出的采样周期
    """
    # 确保按时间排序
    group = group.sort_values("ProgramTime").reset_index(drop=True)

    # --- 1. 动态计算采样周期 (Dynamic Sampling Rate) ---
    # 计算相邻两行 ProgramTime 的差值
    time_diffs = group["ProgramTime"].diff()
    
    # 筛选有效的采样间隔：
    # 必须大于0，且小于0.1秒（假设采样周期不会超过100ms，过滤掉不同周期之间的大停顿）
    valid_intervals = time_diffs[(time_diffs > 0) & (time_diffs < 0.1)]
    
    if not valid_intervals.empty:
        # 取中位数 (Median) 作为最稳定的采样周期，并保留3位小数
        # 中位数能有效抵抗偶尔的抖动或异常值
        calculated_period = round(valid_intervals.median(), 3)
        # 防止计算出0 (如果精度不够)，最小给0.001
        sampling_period = max(calculated_period, 0.001)
    else:
        # 如果数据极其稀疏，无法计算间隔，则使用默认值
        sampling_period = 0.005 

    # --- 2. 识别周期 (Cycle Detection) ---
    nt = group["NodeTime"]
    prev = nt.shift(1)

    RESET_RATIO = 0.1
    ABS_RESET = 0.05
    MAX_GAP_SECONDS = 1.0  # 强制切分阈值

    prog_diff = group["ProgramTime"].diff()
    positive_diffs = prog_diff[prog_diff > 0]
    
    if not positive_diffs.empty:
        stat_threshold = positive_diffs.median() * 5
        prog_threshold = min(stat_threshold, MAX_GAP_SECONDS) if stat_threshold > 0.1 else MAX_GAP_SECONDS
    else:
        prog_threshold = MAX_GAP_SECONDS

    new_cycle = (
        (nt < prev * (1 - RESET_RATIO)) |
        (nt < prev - ABS_RESET) |
        (prog_diff > prog_threshold)
    ).fillna(False)

    group["cycle_id"] = new_cycle.cumsum()

    # --- 3. 聚合计算 ---
    rows = []

    for cid, g in group.groupby("cycle_id"):
        node_path = g["NodePath"].iloc[0]

        if len(g) >= 2:
            # 多行数据：计算极差
            cycle_time = round(g["NodeTime"].max() - g["NodeTime"].min(), 3)
            # 边缘情况：如果多行数据完全相同，视为单次采样
            if cycle_time == 0:
                cycle_time = sampling_period
        else:
            # 单行数据：使用动态计算出的采样周期
            cycle_time = sampling_period

        rows.append({
            "NodePath": node_path,
            "cycle_id": cid,
            "PlanTime": g["PlanTime"].iloc[0],
            "StartProgramTime": g["ProgramTime"].iloc[0],
            "EndProgramTime": g["ProgramTime"].iloc[-1],
            "CycleTime": cycle_time
        })

    return pd.DataFrame(rows)
# -------------------------------------------------------------------------

def analyze_csv(file_path, save_path):
    """分析CSV文件，提取循环时间和相关统计信息"""
    try:
        dtype_dict = {"NodeTime": float, "ProgramTime": float, "NodePath": str, "PlanTime": float}
        df = pd.read_csv(file_path, dtype=dtype_dict)
        validate_file_structure(df)

        df = df.dropna(subset=["NodeTime", "NodePath", "ProgramTime", "PlanTime"])

        all_results = []
        for node_path, group in df.groupby("NodePath"):
            try:
                cycle_summary = process_node_group(group)
                all_results.append(cycle_summary)
            except Exception as e:
                logger.error(f"处理节点路径 {node_path} 时出错: {e}")
                continue

        if not all_results:
            raise ValueError("没有有效数据进行分析")

        results = pd.concat(all_results, ignore_index=True)
        results = results.sort_values(["NodePath", "StartProgramTime"]).reset_index(drop=True)

        # 计算z-scores和异常检测
        if len(results) > 1:
            mean_cycle = results["CycleTime"].mean()
            std_cycle = results["CycleTime"].std()
            if std_cycle == 0:
                results["CycleTime_zscore"] = 0
                results["IsAnomaly"] = False
            else:
                results["CycleTime_zscore"] = (results["CycleTime"] - mean_cycle) / std_cycle
                results["IsAnomaly"] = results["CycleTime_zscore"].abs() > 2
        else:
            results["CycleTime_zscore"] = 0
            results["IsAnomaly"] = False

        anomalies = results[results["IsAnomaly"]].copy()

        summary = (
            results.groupby("NodePath")["CycleTime"]
            .agg([
                ("CycleCount", "count"),
                ("AvgTime", "mean"),
                ("MaxTime", "max"),
                ("MinTime", "min"),
                ("TotalTime", "sum"),
                ("StdTime", "std")
            ])
            .reset_index()
        )

        # 计算EfficiencyRatio
        summary["EfficiencyRatio"] = summary["AvgTime"] / summary["MinTime"]

        # 获取最小和最大Cycle ID
        min_indices = results.groupby("NodePath")["CycleTime"].idxmin()
        max_indices = results.groupby("NodePath")["CycleTime"].idxmax()

        min_cycle_ids = results.loc[min_indices, ["NodePath", "cycle_id"]].rename(columns={"cycle_id": "MinCycleID"})
        max_cycle_ids = results.loc[max_indices, ["NodePath", "cycle_id"]].rename(columns={"cycle_id": "MaxCycleID"})

        summary = summary.merge(min_cycle_ids, on="NodePath", how="left")
        summary = summary.merge(max_cycle_ids, on="NodePath", how="left")

        summary = summary.fillna({"MinCycleID": -1, "MaxCycleID": -1})

        # 保存结果到Excel
        with pd.ExcelWriter(save_path, engine='xlsxwriter') as writer:
            results.to_excel(writer, sheet_name="Cycle_Details", index=False)
            summary.to_excel(writer, sheet_name="Summary", index=False)
            anomalies.to_excel(writer, sheet_name="Anomalies", index=False)

        return results, summary, anomalies

    except Exception as e:
        logger.error(f"分析CSV时出错: {e}")
        raise

def generate_charts(results, anomalies):
    """生成折线图、箱型图和散点图"""
    try:
        pio.templates.default = "plotly_white"

        if 'NodePathDisplay' not in results.columns:
            results['NodePathDisplay'] = results['NodePath']
        if 'NodePathDisplay' not in anomalies.columns and not anomalies.empty:
            anomalies['NodePathDisplay'] = anomalies['NodePath']

        results = results.sort_values('StartProgramTime')

        # 折线图
        line_fig = go.Figure()
        unique_nodes = results['NodePathDisplay'].unique()

        for idx, node in enumerate(unique_nodes):
            node_data = results[results['NodePathDisplay'] == node]
            line_fig.add_trace(go.Scatter(
                x=node_data['PlanTime'],
                y=node_data['CycleTime'],
                name=node,
                mode='lines+markers',
                visible=True if idx == 0 else 'legendonly',
                line=dict(width=2),
                marker=dict(size=6),
                hovertemplate=(
                    f"<b>{node}</b><br>"
                    "计划时间: %{x}<br>"
                    "循环时间: %{y:.3f}秒<br>"
                    "<extra></extra>"
                )
            ))

        dropdown_buttons = [
            dict(label="全部节点", method="update", args=[{"visible": [True] * len(unique_nodes)}])
        ]

        for idx, node in enumerate(unique_nodes):
            visibility = [i == idx for i in range(len(unique_nodes))]
            dropdown_buttons.append(
                dict(label=node, method="update", args=[{"visible": visibility}])
            )

        line_fig.update_layout(
            title=dict(text="节点循环时间趋势", x=0.5, font=dict(size=16)),
            xaxis_title="计划时间 (PlanTime)",
            yaxis_title="循环时间 (秒)",
            height=500,
            showlegend=True,
            margin=dict(l=50, r=50, t=50, b=50),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)',
            dragmode='zoom',
            updatemenus=[dict(
                type="dropdown", direction="down", x=0.0, xanchor="left", y=1.02, yanchor="top",
                showactive=True, buttons=dropdown_buttons
            )]
        )

        config = {
            'displayModeBar': True,
            'displaylogo': False,
            'modeBarButtonsToRemove': ['lasso2d', 'select2d'],
            'responsive': True,
            'scrollZoom': True
        }
        line_html = pio.to_html(line_fig, full_html=False, include_plotlyjs=False, config=config)

        # 箱型图
        box_fig = px.box(results, x="NodePathDisplay", y="CycleTime", points="all", title="各节点循环时间分布（箱型图）")
        box_fig.update_layout(
            xaxis_title="节点路径",
            yaxis_title="循环时间 (秒)",
            height=500,
            showlegend=True,
            margin=dict(l=50, r=50, t=50, b=50),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        box_html = pio.to_html(box_fig, full_html=False, include_plotlyjs=False, config=config)

        # 散点图
        if not anomalies.empty:
            scatter_fig = px.scatter(
                anomalies,
                x="StartProgramTime",
                y="CycleTime",
                color="NodePathDisplay",
                title="异常循环点",
                size_max=10
            )
            scatter_fig.update_layout(
                xaxis_title="程序开始时间",
                yaxis_title="循环时间 (秒)",
                height=500,
                showlegend=True,
                margin=dict(l=50, r=50, t=50, b=50),
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)'
            )
            scatter_html = pio.to_html(scatter_fig, full_html=False, include_plotlyjs=False, config=config)
        else:
            scatter_html = '<div class="info text-center">无异常数据</div>'

        return line_html, box_html, scatter_html

    except Exception as e:
        logger.error(f"生成图表时出错: {e}")
        raise

@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")

@app.route('/static/css/<path:filename>')
def serve_css(filename):
    return send_from_directory(os.path.join(app.static_folder, 'css'), filename)

@app.route('/static/js/<path:filename>')
def serve_js(filename):
    return send_from_directory(os.path.join(app.static_folder, 'js'), filename)

@app.route("/favicon.ico")
def favicon():
    return send_from_directory(app.static_folder, 'favicon.ico')

@app.route('/shutdown', methods=['GET', 'POST'])
def shutdown():
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        return jsonify({"error": "Not running with the Werkzeug Server"}), 400
    func()
    def _exit():
        time.sleep(0.2)
        try:
            os._exit(0)
        except Exception:
            pass
    threading.Thread(target=_exit, daemon=True).start()
    return jsonify({"status": "shutting down"})

@app.route("/api/analyze", methods=["POST"])
def api_analyze():
    uploaded_file = request.files.get("csvFile")
    if not uploaded_file or not allowed_file(uploaded_file.filename):
        return jsonify({"error": "请上传一个有效的CSV文件"}), 400

    try:
        filename = secure_filename(uploaded_file.filename)
        if not filename:
            return jsonify({"error": "无效的文件名"}), 400

        file_id = str(uuid.uuid4())
        safe_basename = filename.rsplit(".", 1)[0]
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        temp_dir = tempfile.gettempdir()
        csv_path = os.path.join(temp_dir, f"{file_id}_{filename}")
        excel_filename = f"{safe_basename}_result.xlsx" if name_has_datetime(safe_basename) else f"{safe_basename}_{ts}_result.xlsx"
        excel_path = os.path.join(UPLOAD_FOLDER, excel_filename)

        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        uploaded_file.save(csv_path)
        logger.info(f"文件已保存: {csv_path}")

        results, summary, anomalies = analyze_csv(csv_path, excel_path)
        line_html, box_html, scatter_html = generate_charts(results, anomalies)

        results_table_html = results.drop(columns=["NodePath"], errors="ignore").rename(
            columns={"NodePathDisplay": "NodePath"}
        ).to_html(classes="table table-striped table-bordered nowrap", index=False, escape=False, table_id="resultsTable")

        summary_display = summary.rename(columns={"NodePath": "NodePathDisplay"})
        summary_display["MinCycleID"] = summary_display["MinCycleID"].apply(lambda x: int(x) if isinstance(x, (int, float)) and x >= 0 else "N/A")
        summary_display["MaxCycleID"] = summary_display["MaxCycleID"].apply(lambda x: int(x) if isinstance(x, (int, float)) and x >= 0 else "N/A")

        summary_table_html = summary_display.to_html(
            classes="table table-striped table-bordered nowrap", index=False, escape=False, table_id="summaryTable"
        )

        anomalies_table_html = anomalies.drop(columns=["NodePath"], errors="ignore").rename(
            columns={"NodePathDisplay": "NodePath"}
        ).to_html(classes="table table-striped table-bordered nowrap", index=False, escape=False, table_id="anomaliesTable")

        download_link = f"/download/{excel_filename}"

        response_json = {
            "results_table_html": results_table_html,
            "summary_table_html": summary_table_html,
            "anomalies_table_html": anomalies_table_html,
            "line_chart_html": line_html,
            "box_chart_html": box_html,
            "scatter_chart_html": scatter_html,
            "download_link": download_link,
            "excel_filename": excel_filename
        }
        try:
            os.remove(csv_path)
        except Exception:
            pass
        return jsonify(response_json)

    except ValueError as ve:
        logger.error(f"ValueError: {ve}")
        return jsonify({"error": f"验证错误: {str(ve)}"}), 400
    except Exception as e:
        logger.error(f"处理文件时出错: {e}")
        return jsonify({"error": f"处理文件失败: {str(e)}"}), 500

@app.route("/download/<path:filename>", methods=["GET"])
def download_file(filename):
    try:
        return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=True)
    except Exception as e:
        logger.error(f"文件下载失败: {e}")
        return jsonify({"error": "文件下载失败"}), 500

def start_server():
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)

if __name__ == "__main__":
    try:
        import webview
        server_thread = threading.Thread(target=start_server, daemon=True)
        server_thread.start()
        window = webview.create_window('Robot Beat Analysis', 'http://127.0.0.1:5000/')
        def on_closed():
            try:
                urllib.request.urlopen('http://127.0.0.1:5000/shutdown')
                os._exit(0)
            except Exception:
                pass
        window.events.closed += on_closed
        webview.start()
    except Exception:
        url = "http://127.0.0.1:5000/"
        webbrowser.open(url)
        start_server()