$(document).ready(function () {
    const uploadBtn = $('#uploadBtn');
    const fileInput = $('#csvFile');
    const fileInfo = $('.file-info');
    const fileName = $('#file-name');
    const removeFileBtn = $('#remove-file');
    const loadingOverlay = $('#loadingOverlay');
    const infoMessage = $('#infoMessage');
    const resultsSection = $('#results-section');
    const summarySection = $('#summary-section');
    const anomaliesSection = $('#anomalies-section');
    const chartSection = $('#chart-section');

    // Handle file input change
    fileInput.on('change', function (e) {
        const file = e.target.files[0];
        if (file) {
            fileName.text(file.name);
            fileInfo.show();
            uploadBtn.prop('disabled', false);
        } else {
            fileInfo.hide();
            uploadBtn.prop('disabled', true);
        }
    });

    // Remove file info
    removeFileBtn.on('click', function () {
        fileInput.val('');
        fileInfo.hide();
        uploadBtn.prop('disabled', true);
    });

    // Handle file upload and analysis
    uploadBtn.on('click', function () {
        const formData = new FormData();
        formData.append('csvFile', fileInput[0].files[0]);

        uploadBtn.prop('disabled', true).html('<i class="bi bi-arrow-repeat"></i> 上传中...');
        loadingOverlay.addClass('active');

        $.ajax({
            url: '/api/analyze',
            method: 'POST',
            data: formData,
            contentType: false,
            processData: false,
            success: function (response) {
                loadingOverlay.removeClass('active');

                if (response.error) {
                    showAlert('error', response.error);
                    uploadBtn.html('<i class="bi bi-arrow-right-circle"></i> 上传并分析').prop('disabled', false);
                    return;
                }

                // 隐藏提示信息
                infoMessage.hide();

                // 填充详细结果表格
                if (response.results_table_html) {
                    $('#resultsTable').html(response.results_table_html);
                    $('#resultsTable').DataTable({
                        responsive: true,
                        searching: true,
                        paging: true,
                        ordering: true,
                        order: [[0, 'asc']],
                        dom: 'lfrtip',
                        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, 'All']],
                        language: {
                            lengthMenu: 'Show _MENU_ entries',
                            search: 'Search:',
                            zeroRecords: 'No matching records found',
                            info: 'Showing _START_ to _END_ of _TOTAL_ entries',
                            infoEmpty: 'Showing 0 to 0 of 0 entries',
                            infoFiltered: '(filtered from _MAX_ total entries)',
                            loadingRecords: 'Loading... ',
                            emptyTable: 'No data available in table',
                            paginate: { first: 'First', previous: 'Prev', next: 'Next', last: 'Last' }
                        },
                        pagingType: 'simple_numbers'
                    });
                    const rFilter = $('#resultsTable').closest('.dataTables_wrapper').find('.dataTables_filter input');
                    rFilter.addClass('form-control form-control-sm').attr('placeholder', 'Search');
                    resultsSection.show();
                }

                // 填充汇总结果表格
                if (response.summary_table_html) {
                    $('#summaryTable').html(response.summary_table_html);
                    $('#summaryTable').DataTable({
                        responsive: true,
                        searching: true,
                        paging: true,
                        ordering: true,
                        order: [[0, 'asc']],
                        dom: 'lfrtip',
                        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, 'All']],
                        language: {
                            lengthMenu: 'Show _MENU_ entries',
                            search: 'Search:',
                            zeroRecords: 'No matching records found',
                            info: 'Showing _START_ to _END_ of _TOTAL_ entries',
                            infoEmpty: 'Showing 0 to 0 of 0 entries',
                            infoFiltered: '(filtered from _MAX_ total entries)',
                            loadingRecords: 'Loading... ',
                            emptyTable: 'No data available in table',
                            paginate: { first: 'First', previous: 'Prev', next: 'Next', last: 'Last' }
                        },
                        pagingType: 'simple_numbers'
                    });
                    const sFilter = $('#summaryTable').closest('.dataTables_wrapper').find('.dataTables_filter input');
                    sFilter.addClass('form-control form-control-sm').attr('placeholder', 'Search');
                    summarySection.show();
                }

                // 填充异常结果表格
                if (response.anomalies_table_html) {
                    $('#anomaliesTable').html(response.anomalies_table_html);
                    $('#anomaliesTable').DataTable({
                        responsive: true,
                        searching: true,
                        paging: true,
                        ordering: true,
                        order: [[0, 'asc']],
                        dom: 'lfrtip',
                        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, 'All']],
                        language: {
                            lengthMenu: 'Show _MENU_ entries',
                            search: 'Search:',
                            zeroRecords: 'No matching records found',
                            info: 'Showing _START_ to _END_ of _TOTAL_ entries',
                            infoEmpty: 'Showing 0 to 0 of 0 entries',
                            infoFiltered: '(filtered from _MAX_ total entries)',
                            loadingRecords: 'Loading... ',
                            emptyTable: 'No data available in table',
                            paginate: { first: 'First', previous: 'Prev', next: 'Next', last: 'Last' }
                        },
                        pagingType: 'simple_numbers'
                    });
                    const aFilter = $('#anomaliesTable').closest('.dataTables_wrapper').find('.dataTables_filter input');
                    aFilter.addClass('form-control form-control-sm').attr('placeholder', 'Search');
                    anomaliesSection.show();
                }

                // 显示图表（按需加载 Plotly）
                if (response.line_chart_html || response.box_chart_html || response.scatter_chart_html) {
                    ensurePlotly().then(function () {
                        if (response.line_chart_html) {
                            $('#lineChart').html(response.line_chart_html);
                        }
                        if (response.box_chart_html) {
                            $('#boxChart').html(response.box_chart_html);
                        }
                        if (response.scatter_chart_html) {
                            $('#scatterChart').html(response.scatter_chart_html);
                        }
                        chartSection.addClass('active');
                    });
                }

                if (response.download_link) {
                    $('#downloadBtn').attr('href', response.download_link).show();
                }
            },
            error: function () {
                loadingOverlay.removeClass('active');
                showAlert('error', '文件上传失败，请重试。');
                uploadBtn.html('<i class="bi bi-arrow-right-circle"></i> 上传并分析').prop('disabled', false);
            }
        });
    });

    function showAlert(type, message) {
        let alertClass = '';
        switch (type) {
            case 'error':
                alertClass = 'alert-danger';
                break;
            case 'success':
                alertClass = 'alert-success';
                break;
            case 'info':
                alertClass = 'alert-info';
                break;
        }
        infoMessage.addClass(alertClass).text(message).show();
    }

    function ensurePlotly() {
        return new Promise(function (resolve) {
            if (window.Plotly) {
                resolve();
                return;
            }
            var s = document.createElement('script');
            s.src = 'https://cdn.plot.ly/plotly-3.3.0.min.js';
            s.onload = function () { resolve(); };
            s.onerror = function () { resolve(); };
            document.head.appendChild(s);
        });
    }
});
