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
import uuid
from datetime import datetime
#需要更新
# 配置日志
logging.basicConfig(
    level=logging.WARNING,  # 只记录警告及以上级别的日志
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# optional: enable CORS
try:
    from flask_cors import CORS
    cors_available = True
except Exception as e:
    logger.warning(f"CORS not available: {e}")
    cors_available = False

# PyInstaller friendly template/static path
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
else:
    base_path = os.path.abspath(os.path.dirname(__file__))

template_folder = os.path.join(base_path, "templates")
static_folder = os.path.join(base_path, "static")

app = Flask(__name__, template_folder=template_folder, static_folder=static_folder)
if cors_available:
    CORS(app)

UPLOAD_FOLDER = os.path.join(base_path, "result")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def validate_file_structure(df):
    """验证CSV文件结构"""
    required_cols = {"NodeTime", "NodePath", "ProgramTime", "PlanTime"}
    missing_cols = required_cols - set(df.columns)
    if missing_cols:
        raise ValueError(f"CSV 缺少字段：{missing_cols}")

    if df.empty:
        raise ValueError("CSV文件为空")


def analyze_csv(file_path, save_path):
    try:
        # logger.info(f"开始分析文件: {file_path}")  # 减少日志输出

        # 读取CSV文件，PlanTime保持为数值格式
        dtype_dict = {"NodeTime": float, "ProgramTime": float, "NodePath": str, "PlanTime": float}
        df = pd.read_csv(file_path, dtype=dtype_dict)

        # 验证文件结构
        validate_file_structure(df)

        # 打印列名和前几行数据，检查PlanTime列是否正常
        # logger.info(f"列名: {df.columns.tolist()}")  # 减少日志输出
        # logger.info(f"前几行数据:\n{df.head()}")  # 减少日志输出

        # 数据清洗
        df = df.dropna(subset=["NodeTime", "NodePath", "ProgramTime", "PlanTime"])

        # 检查PlanTime列是否存在缺失值
        # logger.info(f"PlanTime列缺失值: {df['PlanTime'].isnull().sum()}")  # 减少日志输出

        # 保证PlanTime列没有丢失
        if 'PlanTime' not in df.columns:
            raise ValueError("PlanTime列丢失，请检查CSV文件结构")

        all_results = []
        for node_path, group in df.groupby("NodePath"):
            try:
                group = group.sort_values("ProgramTime").reset_index(drop=True)
                group["cycle_id"] = (group["NodeTime"].diff() < 0).cumsum()

                cycle_summary = group.groupby("cycle_id", as_index=False).agg(
                    StartProgramTime=("ProgramTime", "first"),
                    EndProgramTime=("ProgramTime", "last"),
                    CycleTime=("NodeTime", lambda x: x.max() - x.min()),
                    PlanTime=("PlanTime", "first")  # 确保PlanTime被包含在内
                )

                cycle_summary["NodePath"] = node_path
                cycle_summary = cycle_summary.sort_values("StartProgramTime").reset_index(drop=True)
                cycle_summary["DeltaTime"] = cycle_summary["CycleTime"].diff().fillna(0)
                cycle_summary["DeltaRate"] = cycle_summary["CycleTime"].pct_change().fillna(0)
                all_results.append(cycle_summary)

            except Exception as e:
                logger.error(f"处理节点路径 {node_path} 时出错: {e}")
                continue

        if not all_results:
            raise ValueError("没有足够的有效数据进行分析")

        results = pd.concat(all_results, ignore_index=True)
        results = results.sort_values(["NodePath", "StartProgramTime"]).reset_index(drop=True)

        # 确保结果中包含PlanTime
        # logger.info(f"结果中是否包含PlanTime: {'PlanTime' in results.columns}")  # 减少日志输出

        # 计算标准分数，检测异常
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

        # 生成统计汇总
        summary = (
            results.groupby("NodePath")["CycleTime"]
            .agg([("CycleCount", "count"), ("AvgTime", "mean"), ("MaxTime", "max"),
                  ("MinTime", "min"), ("TotalTime", "sum"), ("StdTime", "std")])
            .reset_index()
        )
        summary["EfficiencyRatio"] = (summary["AvgTime"] / summary["MinTime"]).fillna(0)

        # 保存到 Excel 文件
        try:
            with pd.ExcelWriter(save_path, engine='xlsxwriter') as writer:
                results.to_excel(writer, sheet_name="Cycle_Details", index=False)
                summary.to_excel(writer, sheet_name="Summary", index=False)
                anomalies.to_excel(writer, sheet_name="Anomalies", index=False)
            # logger.info("成功保存Excel文件")  # 减少日志输出
        except Exception as e:
            logger.error(f"保存Excel文件失败: {e}")
            raise ValueError(f"保存分析结果失败：{str(e)}")

        # 清理显示列
        results["NodePathDisplay"] = results["NodePath"].str.replace(r'^rootNode::', '', regex=True)
        summary["NodePathDisplay"] = summary["NodePath"].str.replace(r'^rootNode::', '', regex=True)
        anomalies["NodePathDisplay"] = anomalies["NodePath"].str.replace(r'^rootNode::', '', regex=True)

        # 处理显示字段
        results["DeltaTimeDisplay"] = results["DeltaTime"].round(6).fillna(0)
        results["DeltaRateDisplay"] = (results["DeltaRate"] * 100).round(4).fillna(0).astype(str) + '%'

        return results, summary, anomalies

    except Exception as e:
        logger.error(f"分析过程出错: {e}")
        raise



def generate_charts(results, summary, anomalies):
    try:
        # logger.info("开始生成图表")  # 减少日志输出

        # 设置默认的图表配置
        pio.templates.default = "plotly_white"

        # 确保数据按时间排序
        results = results.copy()
        results['StartProgramTime'] = pd.to_datetime(results['StartProgramTime'])
        results = results.sort_values('StartProgramTime')

        # 创建折线图
        line_fig = go.Figure()
        unique_nodes = results['NodePathDisplay'].unique()

        for idx, node in enumerate(unique_nodes):
            node_data = results[results['NodePathDisplay'] == node]
            line_fig.add_trace(go.Scatter(
                x=node_data['PlanTime'],  # 使用PlanTime作为X轴
                y=node_data['CycleTime'],
                name=node,
                mode='lines+markers',
                visible=True if idx == 0 else 'legendonly',
                line=dict(width=2),
                marker=dict(size=6),
                hovertemplate="<b>%{fullData.name}</b><br>" +
                              "节点路径: %{x}<br>" +
                              "循环时间: %{y:.2f}秒<br>" +
                              "<extra></extra>"
            ))

        # 创建下拉按钮
        dropdown_buttons = [
            dict(
                label="全部节点",
                method="update",
                args=[{"visible": [True] * len(unique_nodes)}]
            )
        ]

        for idx, node in enumerate(unique_nodes):
            visibility = [i == idx for i in range(len(unique_nodes))]
            dropdown_buttons.append(
                dict(
                    label=node,
                    method="update",
                    args=[{"visible": visibility}]
                )
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
            updatemenus=[dict(
                type="dropdown",
                direction="down",
                x=0.0,
                xanchor="left",
                y=1.02,
                yanchor="top",
                showactive=True,
                buttons=dropdown_buttons
            )]
        )

        config = {
            'displayModeBar': True,
            'displaylogo': False,
            'modeBarButtonsToRemove': ['pan2d', 'lasso2d', 'select2d'],
            'responsive': True
        }

        line_html = pio.to_html(line_fig, full_html=False, include_plotlyjs=False, config=config)

        # 箱线图
        box_fig = px.box(
            results,
            x="NodePathDisplay",
            y="CycleTime",
            points="all",
            title="各节点循环时间分布（箱型图）"
        )

        box_fig.update_layout(
            xaxis_title="节点路径",
            yaxis_title="循环时间 (秒)",
            height=500,
            showlegend=True,
            margin=dict(l=50, r=50, t=50, b=50),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )

        box_fig.update_traces(
            marker=dict(size=4),
            hovertemplate="<b>%{x}</b><br>" +
                          "循环时间: %{y:.2f}秒<br>" +
                          "<extra></extra>"
        )

        box_html = pio.to_html(box_fig, full_html=False, include_plotlyjs=False, config=config)

        # 异常点散点图
        if anomalies is not None and not anomalies.empty:
            anomalies = anomalies.copy()
            anomalies['StartProgramTime'] = pd.to_datetime(anomalies['StartProgramTime'])
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

            scatter_fig.update_traces(
                marker=dict(size=8),
                hovertemplate="<b>%{fullData.name}</b><br>" +
                              "程序时间: %{x}<br>" +
                              "循环时间: %{y:.2f}秒<br>" +
                              "<extra></extra>"
            )

            scatter_html = pio.to_html(scatter_fig, full_html=False, include_plotlyjs=False, config=config)
        else:
            scatter_html = '<div class="alert alert-info text-center">无异常数据</div>'

        # logger.info("图表生成完成")  # 减少日志输出
        return line_html, box_html, scatter_html

    except Exception as e:
        logger.error(f"生成图表失败: {e}")
        raise ValueError(f"生成图表失败：{str(e)}")




@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")


@app.route('/favicon.ico')
def favicon():
    return send_from_directory(static_folder, 'favicon.ico')


@app.route("/api/analyze", methods=["POST"])
def api_analyze():
    uploaded_file = request.files.get("file")
    if not uploaded_file or not uploaded_file.filename.lower().endswith(".csv"):
        return jsonify({"error": "请上传 CSV 文件"}), 400

    try:
        # 生成安全的文件名
        filename = secure_filename(uploaded_file.filename)
        if not filename:
            return jsonify({"error": "无效的文件名"}), 400

        # 使用UUID确保文件名唯一
        file_id = str(uuid.uuid4())
        safe_basename = filename.rsplit(".", 1)[0]
        csv_filename = f"{file_id}_{filename}"
        csv_path = os.path.join(UPLOAD_FOLDER, csv_filename)
        excel_filename = f"{file_id}_{safe_basename}_result.xlsx"
        excel_path = os.path.join(UPLOAD_FOLDER, excel_filename)

        # 确保上传目录存在
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)

        # 保存文件
        try:
            uploaded_file.save(csv_path)
            # logger.info(f"文件保存成功: {csv_path}")  # 减少日志输出
        except Exception as e:
            logger.error(f"保存上传文件失败: {e}")
            return jsonify({"error": "文件保存失败"}), 500

        try:
            results, summary, anomalies = analyze_csv(csv_path, excel_path)
            line_html, box_html, scatter_html = generate_charts(results, summary, anomalies)

            results_table_html = results.drop(columns=["NodePath", "DeltaTime", "DeltaRate"]).rename(
                columns={
                    "NodePathDisplay": "NodePath",
                    "DeltaTimeDisplay": "DeltaTime",
                    "DeltaRateDisplay": "DeltaRate"
                }
            ).to_html(classes="table table-striped table-bordered nowrap", index=False, escape=False)

            summary_table_html = summary.rename(columns={"NodePathDisplay": "NodePath"}).to_html(
                classes="table table-striped table-bordered nowrap", index=False, escape=False
            )

            anomalies_table_html = anomalies.drop(columns=["NodePath"], errors="ignore").rename(
                columns={"NodePathDisplay": "NodePath"}
            ).to_html(classes="table table-striped table-bordered nowrap", index=False, escape=False)

            download_link = f"/download/{excel_filename}"

            return jsonify({
                "results_table_html": results_table_html,
                "summary_table_html": summary_table_html,
                "anomalies_table_html": anomalies_table_html,
                "line_chart_html": line_html,
                "box_chart_html": box_html,
                "scatter_chart_html": scatter_html,
                "download_link": download_link,
                "excel_filename": excel_filename
            })

        except Exception as e:
            logger.error(f"分析过程出错: {e}")
            return jsonify({"error": f"分析失败：{str(e)}"}), 500

        finally:
            # 清理临时CSV文件
            try:
                if os.path.exists(csv_path):
                    os.remove(csv_path)
            except Exception as e:
                logger.error(f"清理临时文件失败: {e}")

    except Exception as e:
        logger.error(f"处理请求时发生错误: {e}")
        return jsonify({"error": f"处理请求失败：{str(e)}"}), 500


@app.route("/download/<path:filename>", methods=["GET"])
def download_file(filename):
    try:
        return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=True)
    except Exception as e:
        logger.error(f"文件下载失败: {e}")
        return jsonify({"error": "文件下载失败"}), 500


if __name__ == "__main__":
    url = "http://127.0.0.1:5000/"
    try:
        webbrowser.open(url)
    except Exception as e:
        logger.warning(f"无法自动打开浏览器: {e}")
    app.run(host="127.0.0.1", port=5000, debug=False)
