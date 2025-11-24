$(document).ready(function() {
    $('#upload-btn').click(function() {
        var file = $('#csvFile')[0].files[0];
        if (!file) {
            alert("请选择一个 CSV 文件！");
            return;
        }

        var formData = new FormData();
        formData.append('file', file);

        // 显示加载提示
        $('#info-message').text('文件上传中...');

        $.ajax({
            url: '/api/analyze',
            type: 'POST',
            data: formData,
            contentType: false,
            processData: false,
            success: function(response) {
                $('#info-message').hide();  // 隐藏加载提示

                // 显示表格
                $('#results-table').html(response.results_table_html);
                $('#summary-table').html(response.summary_table_html);
                $('#anomalies-table').html(response.anomalies_table_html);

                // 初始化 DataTables
                $('#results-table table').DataTable({
                    "paging": true,
                    "searching": true,
                    "ordering": true,
                    "info": true
                });

                $('#summary-table table').DataTable({
                    "paging": true,
                    "searching": true,
                    "ordering": true,
                    "info": true
                });

                $('#anomalies-table table').DataTable({
                    "paging": true,
                    "searching": true,
                    "ordering": true,
                    "info": true
                });

                // 显示图表
                $('#line-chart').html(response.line_chart_html);
                $('#box-chart').html(response.box_chart_html);
                $('#scatter-chart').html(response.scatter_chart_html);

                // 显示图表标题
                $('#line-chart-title').show();
                $('#box-chart-title').show();
                $('#scatter-chart-title').show();

                // 显示下载链接
                $('#download-link').attr('href', '/download/' + response.excel_filename).show();
            },
            error: function() {
                $('#info-message').text('上传文件失败，请稍后再试。');
            }
        });
    });
});
