import pandas as pd

# ========================
# 1. 读取 CSV
# ========================
csv_path = r"D:\Workspeace\sunseed\robot\log\pick_drop_jiepai_box1_copy_2025-11-21_17-34-04_1.csv"
df = pd.read_csv(csv_path)

# ========================
# 2. 必要列检查
# ========================
required_cols = {"NodeTime", "NodePath", "ProgramTime"}
missing_cols = required_cols - set(df.columns)
if missing_cols:
    raise ValueError(f"CSV 缺少字段：{missing_cols}")

all_results = []

# ========================
# 3. 按 NodePath 分循环计算
# ========================
for node_path, group in df.groupby("NodePath"):
    group = group.copy()
    group = group.sort_values("ProgramTime").reset_index(drop=True)
    group["cycle_id"] = (group["NodeTime"].diff() < 0).cumsum()

    cycle_summary = (
        group.groupby("cycle_id", group_keys=False)
        .apply(lambda g: pd.Series({
            "StartProgramTime": g["ProgramTime"].iloc[0],
            "EndProgramTime": g["ProgramTime"].iloc[-1],
            "CycleTime": g["NodeTime"].max() - g["NodeTime"].min(),
        }))
        .reset_index()
    )

    cycle_summary["NodePath"] = node_path
    cycle_summary = cycle_summary.sort_values("StartProgramTime").reset_index(drop=True)
    cycle_summary["DeltaTime"] = cycle_summary["CycleTime"].diff()
    cycle_summary["DeltaRate"] = cycle_summary["CycleTime"].pct_change()

    all_results.append(cycle_summary)

results = pd.concat(all_results, ignore_index=True)
results = results.sort_values(["NodePath", "StartProgramTime"]).reset_index(drop=True)

# ========================
# 4. 异常检测
# ========================
results["CycleTime_zscore"] = (results["CycleTime"] - results["CycleTime"].mean()) / results["CycleTime"].std()
results["IsAnomaly"] = results["CycleTime_zscore"].abs() > 2
anomalies = results[results["IsAnomaly"]]

# ========================
# 5. 汇总统计
# ========================
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
summary["EfficiencyRatio"] = summary["AvgTime"] / summary["MinTime"]

# ========================
# 6. 保存到 Excel 多工作表，并绘制图表
# ========================
excel_path = "Robot_CycleTime_Analysis.xlsx"
with pd.ExcelWriter(excel_path, engine='xlsxwriter') as writer:
    results.to_excel(writer, sheet_name="Cycle_Details", index=False)
    summary.to_excel(writer, sheet_name="Summary", index=False)
    anomalies.to_excel(writer, sheet_name="Anomalies", index=False)

    workbook = writer.book
    ws_cycle = writer.sheets["Cycle_Details"]
    ws_summary = writer.sheets["Summary"]
    ws_anomalies = writer.sheets["Anomalies"]

    # ------------------------
    # 6.1 在 Cycle_Details 中绘制循环趋势折线图
    # ------------------------
    chart_cycle = workbook.add_chart({'type': 'line'})
    node_paths = results['NodePath'].unique()
    row_start = 1  # Excel表从第2行开始（0索引）
    for np_idx, node in enumerate(node_paths):
        node_df = results[results["NodePath"] == node]
        col_start = 2 + np_idx  # 为每个节点设置列偏移（可自行调整）
        # 写入辅助列，用于绘图
        ws_cycle.write_column(row_start, col_start, node_df['CycleTime'])
        chart_cycle.add_series({
            'name': node,
            'categories': f'=Cycle_Details!$B${row_start+1}:$B${row_start+len(node_df)}',
            'values': f'=Cycle_Details!${chr(67+np_idx)}${row_start+1}:${chr(67+np_idx)}${row_start+len(node_df)}',
        })
    chart_cycle.set_title({'name': '各节点循环节拍趋势'})
    chart_cycle.set_x_axis({'name': '周期'})
    chart_cycle.set_y_axis({'name': 'CycleTime'})
    ws_cycle.insert_chart('J2', chart_cycle, {'x_scale': 1.5, 'y_scale': 1.5})

    # ------------------------
    # 6.2 在 Summary 中绘制箱型图
    # ------------------------
    chart_box = workbook.add_chart({'type': 'column', 'subtype': 'stacked'})
    chart_box.add_series({
        'name': 'AvgTime',
        'categories': '=Summary!$A$2:$A${}'.format(len(summary)+1),
        'values': '=Summary!$B$2:$B${}'.format(len(summary)+1),
    })
    chart_box.set_title({'name': '各节点平均循环时间'})
    chart_box.set_x_axis({'name': 'NodePath'})
    chart_box.set_y_axis({'name': 'AvgTime'})
    ws_summary.insert_chart('J2', chart_box, {'x_scale': 1.5, 'y_scale': 1.5})

    # ------------------------
    # 6.3 在 Anomalies 中绘制异常散点图
    # ------------------------
    if not anomalies.empty:
        chart_anomaly = workbook.add_chart({'type': 'scatter', 'subtype': 'straight'})
        for np_idx, node in enumerate(node_paths):
            node_anomaly = anomalies[anomalies["NodePath"]==node]
            if node_anomaly.empty:
                continue
            ws_anomalies.write_column(1, 0+np_idx, node_anomaly['StartProgramTime'])
            ws_anomalies.write_column(1, 1+np_idx, node_anomaly['CycleTime'])
            chart_anomaly.add_series({
                'name': node,
                'categories': f'=Anomalies!${chr(65+np_idx)}$2:${chr(65+np_idx)}${1+len(node_anomaly)}',
                'values': f'=Anomalies!${chr(66+np_idx)}$2:${chr(66+np_idx)}${1+len(node_anomaly)}',
            })
        chart_anomaly.set_title({'name': '异常循环点'})
        chart_anomaly.set_x_axis({'name': 'StartProgramTime'})
        chart_anomaly.set_y_axis({'name': 'CycleTime'})
        ws_anomalies.insert_chart('J2', chart_anomaly, {'x_scale': 1.5, 'y_scale': 1.5})

print(f"✅ Excel 文件已生成并绘制图表：{excel_path}")
