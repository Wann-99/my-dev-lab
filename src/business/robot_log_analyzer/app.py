import streamlit as st
import pandas as pd
import re
import plotly.express as px

# ---------------------------------------------------------
# Page Configuration & Styling
# ---------------------------------------------------------
st.set_page_config(page_title="Robot Log Debugger", layout="wide", page_icon="🤖")

st.markdown("""
<style>
.stApp {
    background-color: #f8f9fa;
}
.ide-container {
    background-color: #1e1e1e; 
    padding: 15px; 
    border-radius: 8px; 
    overflow-x: auto; 
    font-family: ui-monospace, 'Fira Code', 'Courier New', monospace; 
    font-size: 13px; 
    line-height: 1.5;
    max-height: 800px;
    overflow-y: auto;
}
.log-line {
    white-space: pre-wrap; 
    padding-left: 10px;
    word-break: break-all;
}
.log-idx {
    color: #607d8b; 
    margin-right: 15px; 
    user-select: none;
    display: inline-block;
    width: 50px;
}
</style>
""", unsafe_allow_html=True)

# ---------------------------------------------------------
# Session State Initialization
# ---------------------------------------------------------
if 'logs_df' not in st.session_state:
    st.session_state.logs_df = pd.DataFrame()
if 'context_idx' not in st.session_state:
    st.session_state.context_idx = None
if 'device_info' not in st.session_state:
    st.session_state.device_info = None

# ---------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------
def render_ide_context(df, center_idx, window=50):
    start_idx = max(0, center_idx - window)
    end_idx = min(len(df), center_idx + window + 1)
    context_df = df.iloc[start_idx:end_idx]
    
    html = "<div class='ide-container'>"
    for i, row in context_df.iterrows():
        color = "#d4d4d4"
        if row['Level'] == 'ERROR': color = "#ff5252"
        elif row['Level'] in ['WARN', 'WARNING']: color = "#ffd740"
        elif row['Level'] == 'DEBUG': color = "#9e9e9e"
        elif row['Level'] == 'INFO': color = "#69f0ae"
        
        bg = "#3d3d3d" if i == center_idx else "transparent"
        border = "border-left: 3px solid #2196f3;" if i == center_idx else "border-left: 3px solid transparent;"
        
        html += f"<div class='log-line' style='background-color: {bg}; {border} color: {color};'><span class='log-idx'>{i:06d}</span>[{row['Timestamp']}] [{row['Level']}] {row['Message']}</div>"
    html += "</div>"
    st.markdown(html, unsafe_allow_html=True)

def parse_logs(files):
    all_logs = []
    pattern = re.compile(r'^\[(.*?)\]\[(.*?)\] (.*)$')
    info_found = None
    
    for file in files:
        # Read and decode, ignoring bad characters
        content = file.getvalue().decode('utf-8', errors='replace')
        lines = content.split('\n')
        
        current_log = None
        for line in lines:
            line = line.rstrip()
            if not line: continue
            
            match = pattern.match(line)
            if match:
                if current_log:
                    all_logs.append(current_log)
                current_log = {
                    'Timestamp': match.group(1),
                    'Level': match.group(2).upper(),
                    'Message': match.group(3)
                }
                if not info_found and 'sw ver' in match.group(3):
                    info_found = match.group(3)
            elif current_log:
                current_log['Message'] += '\n' + line
            else:
                current_log = {'Timestamp': '', 'Level': 'UNKNOWN', 'Message': line}
        if current_log:
            all_logs.append(current_log)
            
    # Chronological sort across all files
    all_logs.sort(key=lambda x: x['Timestamp'])
    
    # State inference logic
    current_state = 'INIT'
    for idx, log in enumerate(all_logs):
        log['Index'] = idx
        msg = log['Message']
        
        if "Transit system state from" in msg:
            state_match = re.search(r'to \[(.*?)\]', msg)
            if state_match:
                current_state = state_match.group(1)
        elif "error" in msg.lower() or log['Level'] == 'ERROR':
            current_state = 'ERROR'
        elif "running" in msg.lower():
            current_state = 'RUNNING'
            
        log['State'] = current_state
        
    return pd.DataFrame(all_logs), info_found

# ---------------------------------------------------------
# Sidebar - Upload & Controls
# ---------------------------------------------------------
with st.sidebar:
    st.header("⚙️ 机器人控制台")
    st.caption("日志分析与调试平台")
    
    uploaded_files = st.file_uploader("📂 上传 .log 文件 (支持多选自动合并)", accept_multiple_files=True)
    
    if st.button("🚀 解析并合并日志", type="primary", use_container_width=True):
        if uploaded_files:
            with st.spinner("正在全力解析多文件并进行时间排序..."):
                df, info = parse_logs(uploaded_files)
                st.session_state.logs_df = df
                st.session_state.device_info = info
                st.session_state.context_idx = None
            st.success(f"解析完成！共 {len(st.session_state.logs_df)} 条日志。")
        else:
            st.warning("请先上传日志文件！")
            
    if not st.session_state.logs_df.empty:
        st.divider()
        if st.session_state.device_info:
            st.info(f"**设备信息**\n\n{st.session_state.device_info}")
            
        df = st.session_state.logs_df
        st.metric("总日志数", len(df))
        
        err_count = len(df[df['Level'] == 'ERROR'])
        warn_count = len(df[df['Level'].isin(['WARN', 'WARNING'])])
        
        col1, col2 = st.columns(2)
        col1.metric("错误数 (ERROR)", err_count, delta_color="inverse")
        col2.metric("警告数 (WARN)", warn_count, delta_color="inverse")

# ---------------------------------------------------------
# Main Application Area
# ---------------------------------------------------------
if st.session_state.logs_df.empty:
    st.info("👈 请在左侧上传机械臂运行日志 (.log) 以开始调试分析。支持上传切片分割的多个日志文件。")
else:
    df = st.session_state.logs_df
    
    tab_timeline, tab_errors, tab_ide = st.tabs(["📈 时间轴与状态", "🚨 错误定位", "💻 IDE 日志视图"])
    
    # --- TAB 1: Timeline & State ---
    with tab_timeline:
        st.subheader("时序分布 (Error & Warning)")
        err_warn_df = df[df['Level'].isin(['ERROR', 'WARNING', 'WARN'])].copy()
        
        if not err_warn_df.empty:
            err_warn_df['DateTime'] = pd.to_datetime(err_warn_df['Timestamp'], errors='coerce')
            
            fig = px.scatter(err_warn_df, x='DateTime', y='Level', color='Level', 
                             custom_data=['Index', 'Message'], 
                             title="异常事件散点图 (框选或点击散点可跳转查看该行上下文)",
                             color_discrete_map={'ERROR': '#ff5252', 'WARNING': '#ffd740', 'WARN': '#ffd740'})
            fig.update_traces(marker=dict(size=10, opacity=0.7, line=dict(width=1, color='DarkSlateGrey')))
            fig.update_layout(template="plotly_white", hovermode="closest")
            
            # Streamlit 1.35+ Native Selection
            selection = st.plotly_chart(fig, on_select="rerun", selection_mode="points", use_container_width=True)
            
            if selection and len(selection.selection["points"]) > 0:
                selected_idx = selection.selection["points"][0]["customdata"][0]
                st.markdown(f"**🎯 已选中时间点错误 (行号 {selected_idx}):**")
                render_ide_context(df, selected_idx, window=20)
        else:
            st.success("🎉 时间轴上未发现 Error 或 Warning 级别日志！")
            
        st.divider()
        st.subheader("🔄 机械臂状态流转 (State Analysis)")
        state_changes = df[df['Message'].str.contains("Transit system state", na=False)]
        if not state_changes.empty:
            st.dataframe(state_changes[['Index', 'Timestamp', 'Level', 'State', 'Message']], use_container_width=True, hide_index=True)
        else:
            st.info("未检测到明显的状态流转记录 (Transit system state)")

    # --- TAB 2: Error Grouping ---
    with tab_errors:
        st.subheader("🚨 错误聚合与定位")
        errors_only = df[df['Level'] == 'ERROR']
        
        if not errors_only.empty:
            col1, col2 = st.columns([1, 2])
            
            with col1:
                st.markdown("##### 📌 错误类型分组")
                # Group by exact message (can be improved with regex to group similar errors)
                err_counts = errors_only['Message'].value_counts().reset_index()
                err_counts.columns = ['Error Message', 'Count']
                st.dataframe(err_counts, use_container_width=True, hide_index=True)
            
            with col2:
                st.markdown("##### 📝 详细错误列表")
                for idx, row in errors_only.iterrows():
                    with st.expander(f"[{row['Timestamp']}] {row['Message'][:80]}..."):
                        st.write(row['Message'])
                        if st.button("🔍 查看完整上下文 (±50行)", key=f"btn_{idx}"):
                            st.session_state.context_idx = idx
                            
            if st.session_state.context_idx is not None:
                st.markdown("---")
                st.subheader(f"🔍 上下文视图 (聚焦行号: {st.session_state.context_idx})")
                if st.button("关闭上下文"):
                    st.session_state.context_idx = None
                    st.rerun()
                render_ide_context(df, st.session_state.context_idx, window=50)
        else:
            st.success("✅ 当前日志中没有任何 ERROR，设备运行良好！")

    # --- TAB 3: IDE View ---
    with tab_ide:
        st.subheader("💻 全局日志搜索与浏览")
        
        col1, col2, col3 = st.columns([4, 2, 2])
        search_q = col1.text_input("🔍 搜索日志内容 (支持正则)")
        level_f = col2.selectbox("等级过滤", ["ALL", "ERROR", "WARNING", "INFO", "DEBUG", "TRACE"])
        jump_idx = col3.number_input("🎯 行号跳转 (查看上下文)", min_value=0, max_value=len(df)-1, value=0, step=1)
        
        if col3.button("跳转并查看该行"):
            st.session_state.context_idx = jump_idx
            
        if st.session_state.context_idx is not None:
            st.warning(f"**当前处于 IDE 上下文聚焦模式** (中心行号: {st.session_state.context_idx})")
            if st.button("❌ 退出聚焦模式，返回列表"):
                st.session_state.context_idx = None
                st.rerun()
            
            render_ide_context(df, st.session_state.context_idx, window=50)
            
        else:
            filtered_df = df
            if level_f != "ALL":
                if level_f == 'WARNING':
                    filtered_df = filtered_df[filtered_df['Level'].isin(['WARNING', 'WARN'])]
                else:
                    filtered_df = filtered_df[filtered_df['Level'] == level_f]
                    
            if search_q:
                filtered_df = filtered_df[filtered_df['Message'].str.contains(search_q, case=False, regex=True, na=False) | filtered_df['Timestamp'].str.contains(search_q, na=False)]
            
            st.markdown(f"*共找到 **{len(filtered_df)}** 条匹配日志*")
            st.dataframe(filtered_df[['Index', 'Timestamp', 'Level', 'State', 'Message']], use_container_width=True, height=600, hide_index=True)