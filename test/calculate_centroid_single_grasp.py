import numpy as np
import time
from scipy.signal import savgol_filter
# import matplotlib.pyplot as plt  # 仅用于生成可视化描述，实际不执行绘图


def optimize_fz_measurement(raw_fz_data, temperature=25.0, calibration_params=None):
    """
    优化Fz测量精度的综合处理函数

    参数:
    raw_fz_data: 原始Fz采样数据列表 (N个样本)
    temperature: 当前传感器温度 (°C)
    calibration_params: 校准参数字典，包含温度补偿和滤波参数

    返回:
    optimized_weight: 优化后的重量值 (N)
    processing_report: 处理过程报告
    """
    # 默认校准参数
    if calibration_params is None:
        calibration_params = {
            'temp_coeff': -0.01,  # 温度系数 (N/°C)
            'ref_temp': 25.0,  # 参考温度 (°C)
            'filter_window': 11,  # 平滑滤波窗口大小
            'z_score_threshold': 3  # 异常值检测阈值
        }

    report = []
    report.append(f"原始数据: {len(raw_fz_data)}个样本，范围: [{min(raw_fz_data):.3f}, {max(raw_fz_data):.3f}] N")

    # 1. 异常值去除 (Z-score方法)
    data = np.array(raw_fz_data)
    z_scores = np.abs((data - np.mean(data)) / np.std(data))
    filtered_data = data[z_scores < calibration_params['z_score_threshold']]
    report.append(f"异常值去除: 移除{len(data) - len(filtered_data)}个异常点，剩余{len(filtered_data)}个样本")

    # 2. 平滑滤波 (Savitzky-Golay滤波)
    if len(filtered_data) >= calibration_params['filter_window']:
        smoothed_data = savgol_filter(filtered_data,
                                      window_length=calibration_params['filter_window'],
                                      polyorder=2)
        report.append(f"平滑滤波: 窗口={calibration_params['filter_window']}，多项式阶数=2")
    else:
        smoothed_data = filtered_data
        report.append(f"平滑滤波: 样本量不足，使用原始滤波数据")

    # 3. 温度补偿
    temp_diff = temperature - calibration_params['ref_temp']
    temp_compensation = calibration_params['temp_coeff'] * temp_diff
    compensated_mean = np.mean(smoothed_data) + temp_compensation
    report.append(f"温度补偿: 温度={temperature}°C，补偿值={temp_compensation:.4f}N，补偿后均值={compensated_mean:.4f}N")

    # 4. 计算最终重量 (保留两位小数)
    optimized_weight = round(compensated_mean, 2)

    return optimized_weight, report


# 模拟数据生成 (模拟带噪声和温度漂移的Fz采样)
def generate_simulated_data(n_samples=100, true_weight=12.5, temp=30.0, noise_level=0.15):
    """生成模拟的Fz采样数据，包含噪声、温度漂移和异常值"""
    # 基础漂移 (温度导致)
    temp_drift = 0.01 * (temp - 25.0)  # 每度0.01N漂移
    # 随机噪声
    noise = np.random.normal(0, noise_level, n_samples)
    # 信号
    data = true_weight + temp_drift + noise
    # 添加2个异常值
    outlier_indices = np.random.choice(n_samples, 2, replace=False)
    data[outlier_indices] += np.random.normal(3, 1, 2) * noise_level
    return data.tolist()


# 主流程演示
if __name__ == "__main__":
    # 1. 模拟传感器数据 (100个样本，真实重量12.5N，温度30°C)
    raw_data = generate_simulated_data(n_samples=100, true_weight=12.5, temp=30.0)

    # 2. 优化处理
    calibration_params = {
        'temp_coeff': -0.01,  # 温度每升高1°C，重量读数增加0.01N，需减去
        'ref_temp': 25.0,
        'filter_window': 11,
        'z_score_threshold': 3
    }
    optimized_W, report = optimize_fz_measurement(
        raw_fz_data=raw_data,
        temperature=30.0,
        calibration_params=calibration_params
    )

    # 3. 保存结果到文件
    output_filename = "Fz测量精度优化报告.md"
    with open(output_filename, 'w', encoding='utf-8') as f:
        f.write("# Fz测量精度优化报告\n\n")
        f.write(f"## 优化前后对比\n")
        f.write(f"| 指标          | 原始数据       | 优化后数据     | 改进幅度  |\n")
        f.write(f"|---------------|----------------|----------------|-----------|\n")
        f.write(
            f"| 平均值        | {np.mean(raw_data):.4f} N | {optimized_W:.4f} N | {'%.2f%%' % ((np.mean(raw_data) - optimized_W) / np.mean(raw_data) * 100)} |\n")
        f.write(f"| 标准差        | {np.std(raw_data):.4f} N | -              | -         |\n")
        f.write(
            f"| 与真实值偏差  | {np.abs(np.mean(raw_data) - 12.5):.4f} N | {np.abs(optimized_W - 12.5):.4f} N | {'%.2f%%' % ((np.abs(np.mean(raw_data) - 12.5) - np.abs(optimized_W - 12.5)) / np.abs(np.mean(raw_data) - 12.5) * 100)} |\n\n")

        f.write(f"## 处理步骤与效果\n")
        for i, step in enumerate(report, 1):
            f.write(f"{i}. {step}\n")

        f.write(f"\n## 优化参数设置\n")
        f.write(f"| 参数               | 值              | 说明                     |\n")
        f.write(f"|--------------------|-----------------|--------------------------|\n")
        f.write(f"| 采样点数           | 100             | 1秒@100Hz                |\n")
        f.write(f"| 异常值阈值(Z-score)| 3               | 移除3倍标准差外的异常点  |\n")
        f.write(f"| 平滑窗口大小       | 11              | Savitzky-Golay滤波窗口   |\n")
        f.write(f"| 温度系数           | -0.01 N/°C      | 温度每升高1°C补偿-0.01N  |\n")
        f.write(f"| 参考温度           | 25°C            | 校准参考温度             |\n\n")

        f.write(f"## 推荐硬件优化方案\n")
        f.write(f"1. **传感器校准**：每季度进行一次六维全参数校准，更新耦合矩阵\n")
        f.write(f"2. **安装优化**：使用激光水平仪校准垂直度，确保倾角<0.1°\n")
        f.write(f"3. **数据采集**：抓取后稳定0.5秒再采样，采样率≥100Hz，采样时长≥1秒\n")
        f.write(f"4. **温度控制**：测量前传感器预热30分钟，环境温度波动控制在±2°C内\n")

    print(f"优化后重量: {optimized_W} N")
    print(f"优化报告已保存至: {output_filename}")
    print(f"生成成功")