document.addEventListener("DOMContentLoaded", function () {
    const dropZone = document.getElementById("dropZone");
    const browseBtn = document.getElementById("browseBtn");
    const fileInfo = document.getElementById("fileInfo");
    const csvFileInput = document.getElementById("csvFile");
    const statusEl = document.getElementById("status");
    const uploadBtn = document.getElementById("uploadBtn");
    const downloadArea = document.getElementById("downloadArea");
    const chartsArea = document.getElementById("chartsArea");
    const tablesArea = document.getElementById("tablesArea");
    const downloadLink = document.getElementById("downloadLink");

    // 处理文件选择
    function handleFileSelect(file) {
        if (file && file.name.endsWith(".csv")) {
            fileInfo.textContent = `已选择：${file.name}`;
            fileInfo.style.display = "block";
            dropZone.classList.add("uploaded");
            uploadBtn.style.display = "block";
            statusEl.style.display = "block";
            statusEl.className = "alert alert-info mt-3";
            statusEl.textContent = "文件已选择，点击开始分析按钮进行分析";
        } else {
            statusEl.style.display = "block";
            statusEl.className = "alert alert-danger mt-3";
            statusEl.textContent = "请上传有效的CSV文件。";
            uploadBtn.style.display = "none";
        }
    }

    // 浏览按钮点击事件
    browseBtn.addEventListener("click", () => {
        csvFileInput.click();
    });

    // 文件输入变化事件
    csvFileInput.addEventListener("change", (e) => {
        const file = e.target.files[0];
        handleFileSelect(file);
    });

    // 拖拽事件处理
    dropZone.addEventListener("dragover", (e) => {
        e.preventDefault();
        dropZone.classList.add("drag-over");
    });

    dropZone.addEventListener("dragleave", () => {
        dropZone.classList.remove("drag-over");
    });

    dropZone.addEventListener("drop", (e) => {
        e.preventDefault();
        dropZone.classList.remove("drag-over");
        const file = e.dataTransfer.files[0];
        csvFileInput.files = e.dataTransfer.files;
        handleFileSelect(file);
    });

    // 更新图表
        // 更新图表
        // 更新图表
    function updateChart(chartId, html) {
        const container = document.getElementById(chartId);
        if (container) {
            // 显示加载状态
            container.innerHTML = '<div class="loading-spinner"><div class="spinner-border" role="status"><span class="sr-only">加载中...</span></div></div>';

            // 等待一小段时间后更新图表
            setTimeout(() => {
                try {
                    // 创建一个新的div来容纳图表
                    const chartDiv = document.createElement('div');
                    chartDiv.className = 'plotly-graph-div';
                    chartDiv.style.width = '100%';
                    chartDiv.style.height = '400px';

                    // 清空容器并添加新的图表div
                    container.innerHTML = '';
                    container.appendChild(chartDiv);

                    // 如果HTML包含完整的图表代码，直接插入
                    if (html.includes('plotly')) {
                        chartDiv.innerHTML = html;
                    } else {
                        // 否则，尝试解析JSON数据并创建新图表
                        const data = JSON.parse(html);
                        Plotly.newPlot(chartDiv, data.data, data.layout, {responsive: true});
                    }

                    // 确保图表正确渲染
                    window.dispatchEvent(new Event('resize'));

                } catch (error) {
                    console.error('图表更新失败:', error);
                    container.innerHTML = '<div class="alert alert-danger">图表加载失败</div>';
                }
            }, 100);
        }
    }



    // 上传按钮点击事件
    uploadBtn.addEventListener("click", function() {
        const file = csvFileInput.files[0];
        if (!file) {
            statusEl.textContent = "请先选择文件";
            return;
        }

        const formData = new FormData();
        formData.append("file", file);

        statusEl.className = "alert alert-info mt-3";
        statusEl.textContent = "正在分析中，请稍候...";
        uploadBtn.disabled = true;

        axios.post("/api/analyze", formData, {
            headers: { "Content-Type": "multipart/form-data" },
            timeout: 120000
        })
        .then(function(resp) {
            const data = resp.data;
            if (data.error) {
                statusEl.className = "alert alert-danger mt-3";
                statusEl.textContent = data.error;
                return;
            }

            // 更新图表
            updateChart("lineChart", data.line_chart_html || '<div class="alert alert-warning">无数据</div>');
            updateChart("boxChart", data.box_chart_html || '<div class="alert alert-warning">无数据</div>');
            updateChart("scatterChart", data.scatter_chart_html || '<div class="alert alert-warning">无数据</div>');

            // 更新表格
            document.getElementById("results_table_container").innerHTML = data.results_table_html || "<p>无数据</p>";
            document.getElementById("summary_table_container").innerHTML = data.summary_table_html || "<p>无数据</p>";
            document.getElementById("anomalies_table_container").innerHTML = data.anomalies_table_html || "<p>无数据</p>";

            // 显示下载链接
            if (data.download_link) {
                downloadLink.href = data.download_link;
                downloadArea.style.display = "block";
            }

            // 显示结果区域
            chartsArea.style.display = "block";
            tablesArea.style.display = "block";

            statusEl.className = "alert alert-success mt-3";
            statusEl.textContent = "分析完成！";
        })
        .catch(function(err) {
            console.error(err);
            const msg = (err.response && err.response.data && err.response.data.error) ? err.response.data.error : (err.message || "请求失败");
            statusEl.className = "alert alert-danger mt-3";
            statusEl.textContent = `错误：${msg}`;
        })
        .finally(function() {
            uploadBtn.disabled = false;
        });
    });
});
