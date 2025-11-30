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
logging.basicConfig(
    level=logging.WARNING,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Optional: Enable CORS
try:
    from flask_cors import CORS
    cors_available = True
except Exception as e:
    logger.warning(f"CORS not available: {e}")
    cors_available = False

# Set template and static folders
template_folder = os.path.join(os.path.dirname(__file__), "templates")
# print(f"Template folder path: {template_folder}")
static_folder = os.path.join(os.path.dirname(__file__), "static")

app = Flask(__name__, template_folder=template_folder, static_folder=static_folder,static_url_path="/static")
# print(f"Flask is looking for templates in: {app.template_folder}")
if cors_available:
    CORS(app)

# File upload and result directory
UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), "result")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def validate_file_structure(df):
    """Validate CSV file structure."""
    required_cols = {"NodeTime", "NodePath", "ProgramTime", "PlanTime"}
    missing_cols = required_cols - set(df.columns)
    if missing_cols:
        raise ValueError(f"CSV missing columns: {missing_cols}")
    if df.empty:
        raise ValueError("CSV file is empty")

def process_node_group(group):
    """Process each node group and calculate cycle details."""
    group = group.sort_values("ProgramTime").reset_index(drop=True)
    group["cycle_id"] = (group["NodeTime"].diff() < 0).cumsum()

    cycle_summary = group.groupby("cycle_id", as_index=False).agg(
        StartProgramTime=("ProgramTime", "first"),
        EndProgramTime=("ProgramTime", "last"),
        CycleTime=("NodeTime", lambda x: x.max() - x.min()),
        PlanTime=("PlanTime", "first")
    )

    cycle_summary["NodePath"] = group["NodePath"].iloc[0]
    cycle_summary = cycle_summary.sort_values("StartProgramTime").reset_index(drop=True)
    cycle_summary["DeltaTime"] = cycle_summary["CycleTime"].diff().fillna(0)
    cycle_summary["DeltaRate"] = cycle_summary["CycleTime"].pct_change().fillna(0)

    return cycle_summary

def analyze_csv(file_path, save_path):
    """Analyze CSV file to extract cycle time and related statistics."""
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
                logger.error(f"Error processing node path {node_path}: {e}")
                continue

        if not all_results:
            raise ValueError("No valid data for analysis")

        results = pd.concat(all_results, ignore_index=True)
        results = results.sort_values(["NodePath", "StartProgramTime"]).reset_index(drop=True)

        # Calculate z-scores and anomalies
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
            .agg([("CycleCount", "count"), ("AvgTime", "mean"), ("MaxTime", "max"), ("MinTime", "min"),
                  ("TotalTime", "sum"), ("StdTime", "std")])
            .reset_index()
        )

        # 新增 CycleSumTime 计算
        # 计算每个节点路径的循环时间总和
        # cycle_sum_time = results.groupby("NodePath")["CycleTime"].sum().reset_index()
        # cycle_sum_time.rename(columns={"CycleTime": "CycleSumTime"}, inplace=True)

        # 合并到 summary 中
        # summary = summary.merge(cycle_sum_time, on="NodePath", how="left")

        summary["EfficiencyRatio"] = (summary["AvgTime"] / summary["MinTime"]).fillna(0)

        min_indices = results.groupby("NodePath")["CycleTime"].idxmin()
        max_indices = results.groupby("NodePath")["CycleTime"].idxmax()

        min_cycle_ids = results.loc[min_indices, ["NodePath", "cycle_id"]].rename(columns={"cycle_id": "MinCycleID"})
        max_cycle_ids = results.loc[max_indices, ["NodePath", "cycle_id"]].rename(columns={"cycle_id": "MaxCycleID"})

        summary = summary.merge(min_cycle_ids, on="NodePath", how="left")
        summary = summary.merge(max_cycle_ids, on="NodePath", how="left")

        summary = summary.fillna({"MinCycleID": -1, "MaxCycleID": -1})

        # Save results to Excel
        with pd.ExcelWriter(save_path, engine='xlsxwriter') as writer:
            results.to_excel(writer, sheet_name="Cycle_Details", index=False)
            summary.to_excel(writer, sheet_name="Summary", index=False)
            anomalies.to_excel(writer, sheet_name="Anomalies", index=False)

        return results, summary, anomalies

    except Exception as e:
        logger.error(f"Error analyzing CSV: {e}")
        raise

def generate_charts(results, summary, anomalies):
    """Generate line, box, and scatter charts."""
    try:
        pio.templates.default = "plotly_white"

        # Check if 'NodePathDisplay' exists in anomalies, if not, fall back to 'NodePath'
        if 'NodePathDisplay' not in anomalies.columns:
            logger.warning("'NodePathDisplay' column is missing in anomalies. Using 'NodePath' as fallback.")
            anomalies['NodePathDisplay'] = anomalies['NodePath']  # Fallback to 'NodePath'

        # Check if 'NodePathDisplay' is also missing in results, fallback if necessary
        if 'NodePathDisplay' not in results.columns:
            logger.warning("'NodePathDisplay' column is missing in results. Using 'NodePath' as fallback.")
            results['NodePathDisplay'] = results['NodePath']  # Fallback to 'NodePath'

        # Log DataFrames for debugging
        logger.debug(f"Results DataFrame (with NodePathDisplay): {results.head()}")
        logger.debug(f"Anomalies DataFrame (with NodePathDisplay): {anomalies.head()}")

        # results['StartProgramTime'] = pd.to_datetime(results['StartProgramTime'])
        results = results.sort_values('StartProgramTime')

        # Line chart generation (same as before)
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
                hovertemplate="<b>%{fullData.name}</b><br>" +
                              "节点路径: %{x}<br>" +
                              "循环时间: %{y:.3f}秒<br>" +
                              "<extra></extra>"
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
            updatemenus=[dict(
                type="dropdown", direction="down", x=0.0, xanchor="left", y=1.02, yanchor="top",
                showactive=True, buttons=dropdown_buttons
            )]
        )

        config = {'displayModeBar': True, 'displaylogo': False, 'modeBarButtonsToRemove': ['pan2d', 'lasso2d', 'select2d'], 'responsive': True}
        line_html = pio.to_html(line_fig, full_html=False, include_plotlyjs=False, config=config)

        # Box chart generation (same as before)
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

        # Scatter chart for anomalies
        if anomalies is not None and not anomalies.empty:
            # anomalies['StartProgramTime'] = pd.to_datetime(anomalies['StartProgramTime'])
            scatter_fig = px.scatter(
                anomalies,
                x="StartProgramTime",
                y="CycleTime",
                color="NodePathDisplay",  # Now safe to use NodePathDisplay
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
            scatter_html = '<div class="-info text-center">无异常数据</div>'

        return line_html, box_html, scatter_html

    except Exception as e:
        logger.error(f"Error generating charts: {e}")
        raise




@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")

@app.route('/static/css/<path:filename>')
def css_files(filename):
    return send_from_directory(os.path.join(static_folder, 'css'), filename)

@app.route('/static/js/<path:filename>')
def js_files(filename):
    return send_from_directory(os.path.join(static_folder, 'js'), filename)


@app.route("/favicon.ico")
def favicon():
    return send_from_directory(static_folder, 'favicon.ico')
@app.route("/api/analyze", methods=["POST"])
def api_analyze():
    uploaded_file = request.files.get("csvFile")
    if not uploaded_file or not uploaded_file.filename.lower().endswith(".csv"):
        return jsonify({"error": "Please upload a CSV file"}), 400

    try:
        filename = secure_filename(uploaded_file.filename)
        if not filename:
            return jsonify({"error": "Invalid file name"}), 400

        file_id = str(uuid.uuid4())
        safe_basename = filename.rsplit(".", 1)[0]
        csv_filename = f"{file_id}_{filename}"
        csv_path = os.path.join(UPLOAD_FOLDER, csv_filename)
        excel_filename = f"{file_id}_{safe_basename}_result.xlsx"
        excel_path = os.path.join(UPLOAD_FOLDER, excel_filename)

        os.makedirs(UPLOAD_FOLDER, exist_ok=True)

        uploaded_file.save(csv_path)
        logger.debug(f"File saved: {csv_path}")

        # Process the CSV
        results, summary, anomalies = analyze_csv(csv_path, excel_path)
        line_html, box_html, scatter_html = generate_charts(results, summary, anomalies)

        # Generate the HTML tables
        results_table_html = results.drop(columns=["NodePath", "DeltaTime", "DeltaRate"]).rename(
            columns={"NodePathDisplay": "NodePath", "DeltaTimeDisplay": "DeltaTime", "DeltaRateDisplay": "DeltaRate"}
        ).to_html(classes="table table-striped table-bordered nowrap", index=False, escape=False)

        summary_display = summary.rename(columns={"NodePathDisplay": "NodePath"})
        summary_display["MinCycleID"] = summary_display["MinCycleID"].apply(lambda x: int(x) if x >= 0 else "N/A")
        summary_display["MaxCycleID"] = summary_display["MaxCycleID"].apply(lambda x: int(x) if x >= 0 else "N/A")
        # summary_display["CycleSumTime"] = summary_display["CycleSumTime"].round(4)

        summary_table_html = summary_display.to_html(
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

    except ValueError as ve:
        logger.error(f"ValueError: {ve}")
        return jsonify({"error": f"Validation error: {str(ve)}"}), 400
    except Exception as e:
        logger.error(f"Error processing file: {e}")
        return jsonify({"error": f"Failed to process file: {str(e)}"}), 500


@app.route("/download/<path:filename>", methods=["GET"])
def download_file(filename):
    try:
        return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=True)
    except Exception as e:
        logger.error(f"File download failed: {e}")
        return jsonify({"error": "File download failed"}), 500

if __name__ == "__main__":
    # url = "http://127.0.0.1:5000/"
    # try:
    #     webbrowser.open(url)
    # except Exception as e:
    #     logger.warning(f"Unable to automatically open browser: {e}")
    # app.run(host="127.0.0.1", port=5000, debug=False)
    # print(app.url_map)
    app.run(debug=True)


