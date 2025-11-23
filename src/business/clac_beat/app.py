import os
import sys
import webbrowser
from flask import Flask, request, jsonify, send_from_directory, render_template
import pandas as pd
import plotly.express as px
import plotly.io as pio

# optional: enable CORS
try:
    from flask_cors import CORS

    cors_available = True
except Exception:
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


def analyze_csv(file_path, save_path):
    dtype_dict = {"NodeTime": float, "ProgramTime": float, "NodePath": str}
    df = pd.read_csv(file_path, dtype=dtype_dict)

    required_cols = {"NodeTime", "NodePath", "ProgramTime"}
    missing_cols = required_cols - set(df.columns)
    if missing_cols:
        raise ValueError(f"CSV 缺少字段：{missing_cols}")

    all_results = []
    for node_path, group in df.groupby("NodePath"):
        group = group.sort_values("ProgramTime").reset_index(drop=True)
        group["cycle_id"] = (group["NodeTime"].diff() < 0).cumsum()

        cycle_summary = group.groupby("cycle_id", as_index=False).agg(
            StartProgramTime=("ProgramTime", "first"),
            EndProgramTime=("ProgramTime", "last"),
            CycleTime=("NodeTime", lambda x: x.max() - x.min())
        )
        cycle_summary["NodePath"] = node_path
        cycle_summary = cycle_summary.sort_values("StartProgramTime").reset_index(drop=True)
        cycle_summary["DeltaTime"] = cycle_summary["CycleTime"].diff()
        cycle_summary["DeltaRate"] = cycle_summary["CycleTime"].pct_change()
        all_results.append(cycle_summary)

    results = pd.concat(all_results, ignore_index=True)
    results = results.sort_values(["NodePath", "StartProgramTime"]).reset_index(drop=True)

    results["CycleTime_zscore"] = (results["CycleTime"] - results["CycleTime"].mean()) / results["CycleTime"].std()
    results["IsAnomaly"] = results["CycleTime_zscore"].abs() > 2
    anomalies = results[results["IsAnomaly"]].copy()

    summary = (
        results.groupby("NodePath")["CycleTime"]
        .agg([("CycleCount", "count"), ("AvgTime", "mean"), ("MaxTime", "max"), ("MinTime", "min"),
              ("TotalTime", "sum"), ("StdTime", "std")])
        .reset_index()
    )
    summary["EfficiencyRatio"] = summary["AvgTime"] / summary["MinTime"]

    with pd.ExcelWriter(save_path, engine='xlsxwriter') as writer:
        results.to_excel(writer, sheet_name="Cycle_Details", index=False)
        summary.to_excel(writer, sheet_name="Summary", index=False)
        anomalies.to_excel(writer, sheet_name="Anomalies", index=False)

    results["NodePathDisplay"] = results["NodePath"].str.replace(r'^rootNode::', '', regex=True)
    summary["NodePathDisplay"] = summary["NodePath"].str.replace(r'^rootNode::', '', regex=True)
    anomalies["NodePathDisplay"] = anomalies["NodePath"].str.replace(r'^rootNode::', '', regex=True)

    results["DeltaTimeDisplay"] = results["DeltaTime"].round(6).fillna(0)
    results["DeltaRateDisplay"] = (results["DeltaRate"] * 100).round(4).fillna(0).astype(str) + '%'

    return results, summary, anomalies


def generate_charts(results, summary, anomalies):
    # 设置默认的图表配置
    pio.templates.default = "plotly_white"

    # 确保数据按时间排序
    results = results.sort_values('StartProgramTime')

    # 折线图
    line_fig = px.line(
        results,
        x="StartProgramTime",
        y="CycleTime",
        color="NodePathDisplay",
        title="各节点循环节拍趋势",
        line_shape="linear",
        markers=True
    )

    line_fig.update_layout(
        xaxis_title="程序开始时间",
        yaxis_title="循环时间 (秒)",
        legend_title="节点路径",
        hovermode="x unified",
        height=500,
        showlegend=True,
        margin=dict(l=50, r=50, t=50, b=50),
        plot_bgcolor='rgba(0,0,0,0)',
        paper_bgcolor='rgba(0,0,0,0)'
    )

    line_fig.update_traces(
        line=dict(width=2),
        marker=dict(size=6),
        hovertemplate="<b>%{fullData.name}</b><br>" +
                      "程序时间: %{x}<br>" +
                      "循环时间: %{y:.2f}秒<br>" +
                      "<extra></extra>"
    )

    # 生成HTML
    config = {
        'displayModeBar': True,
        'displaylogo': False,
        'modeBarButtonsToRemove': ['pan2d', 'lasso2d', 'select2d'],
        'responsive': True
    }

    # 直接返回图表的JSON数据
    line_json = line_fig.to_json()
    line_html = pio.to_html(line_fig, full_html=False, include_plotlyjs=False, config=config)

    # 箱线图
    box_fig = px.box(
        results,
        x="NodePathDisplay",
        y="CycleTime",
        points="all",
        title="各节点循环时间分布（箱型图）",
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

    box_json = box_fig.to_json()
    box_html = pio.to_html(box_fig, full_html=False, include_plotlyjs=False, config=config)

    # 异常点散点图
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

        scatter_fig.update_traces(
            marker=dict(size=8),
            hovertemplate="<b>%{fullData.name}</b><br>" +
                          "程序时间: %{x}<br>" +
                          "循环时间: %{y:.2f}秒<br>" +
                          "<extra></extra>"
        )

        scatter_json = scatter_fig.to_json()
        scatter_html = pio.to_html(scatter_fig, full_html=False, include_plotlyjs=False, config=config)
    else:
        scatter_json = None
        scatter_html = '<div class="alert alert-info text-center">无异常数据</div>'

    return line_html, box_html, scatter_html


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

    filename = uploaded_file.filename
    safe_basename = filename.rsplit(".", 1)[0]
    csv_path = os.path.join(UPLOAD_FOLDER, filename)
    excel_filename = f"{safe_basename}_result.xlsx"
    excel_path = os.path.join(UPLOAD_FOLDER, excel_filename)

    uploaded_file.save(csv_path)

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
        return jsonify({"error": f"处理失败：{e}"}), 500


@app.route("/download/<path:filename>", methods=["GET"])
def download_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=True)


if __name__ == "__main__":
    url = "http://127.0.0.1:5000/"
    try:
        webbrowser.open(url)
    except Exception:
        pass
    app.run(host="127.0.0.1", port=5000, debug=False)
