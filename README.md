# Flexiv Robot 项目重构说明

本次重构目标：统一入口、理清业务与工具模块、减少重复脚本，保留现有示例与业务逻辑。

## 新的项目结构（核心）
- `src/cli.py`: 统一命令行入口，提供子命令。
- `src/__main__.py`: 支持 `python -m src` 启动 CLI。
- `src/business/rdk_Programs/`: 保留原业务模块，如 `demo_robot_torque.py`、`FlexivForceDataCollector.py`。
- `src/utils/`: 工具与封装，如 `logger_util.py`、`flexivrdk_helper.py`、`tool_utils.py`。
- `src/data/csv_utils.py`: 数据写入工具。
- `test/example_py/`: 官方或示例脚本，未纳入统一 CLI。

## 安装依赖
部分业务运行依赖 `flexivrdk` 与 `spdlog` 等第三方库：

```powershell
pip install flexivrdk spdlog
```

## 使用方法
统一入口：

```powershell
python -m src --help
```

子命令及参数：

- `torque`: 运行机器人扭矩读取与力控示例
  - 参数：`--config` 指定配置文件；`--robot-sn` 覆盖序列号；`--loops` 连续执行次数（默认 1）
  - 示例：
    ```powershell
    python -m src torque --config config/config.json --robot-sn Rizon4s-XXXXXX --loops 3
    ```

- `collect-force`: 采集力数据并保存到 CSV
  - 参数：`--config` 指定配置文件；`--robot-sn` 覆盖序列号；`--duration` 采集时长（秒）；`--sampling-rate` 采样频率（Hz）
  - 示例：
    ```powershell
    python -m src collect-force --config config/config.json --duration 10 --sampling-rate 100
    ```

说明：
- `--config` 为 JSON 配置文件路径，默认 `config/config.json`。
- 若未提供 `--robot-sn`，将从配置 `robot.robot_sn` 读取。
- 所有子命令在解析完成后才进行业务模块导入，保证 `--help` 始终可用。

## 配置文件示例
`config/config.json` 示例（请根据实际调整）：

```json
{
  "robot": {
    "robot_sn": "Rizon4s-123456"
  },
  "parameters": {
    "force_collection": {
      "duration": 10,
      "sampling_rate": 100
    }
  }
}
```

## 兼容性与注意事项
- 为保证 `--help` 可用，CLI 采用惰性导入，只有在执行子命令时才加载依赖模块。
- 运行业务命令需确保 `flexivrdk` 可用且机器人连接正常。
- 旧入口脚本如 `src/business/rdk_Programs/main.py` 保留但不再推荐，建议改用统一 CLI。

## 数据输出与保存
- 力数据采集使用 `DataWriter` 写入 `data/` 文件夹，命名形如：`force_data_YYYYMMDD_SEQ.csv`
- 表头由采集器首次写入时生成，包含：时间戳、Fx/Fy/Fz、Mx/My/Mz、工具质量、TCP 位置、耗时等字段（以采集器实现为准）
- 日志按天生成，默认写入 `logs/`（具体行为由 `CommonLogger` 决定）

## 常见问题
- 运行 `python -m src --help` 报错：通常为依赖导入或配置路径问题，检查 `libs/` 与 `config/config.json`。
- 无法连接机器人：确认 `robot_sn` 正确，网络/电源/急停状态正常，`flexivrdk` 版本与设备兼容。
- CSV 未生成：确认采集时长与采样率为正数，并检查程序日志输出。

## 后续计划（可选）
- 整理 `test/example_py` 中脚本为统一子命令或文档链接。
- 为 `src/business/PP_Programs` 添加合适的 CLI 子命令封装。
