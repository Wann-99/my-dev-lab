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

子命令：

- `torque`: 运行机器人扭矩读取与力控示例
  ```powershell
  python -m src torque --config config/config.json [--robot-sn Rizon4s-XXXXXX]
  ```

- `collect-force`: 采集力数据并保存到 CSV
  ```powershell
  python -m src collect-force --config config/config.json [--robot-sn Rizon4s-XXXXXX] [--duration 10] [--sampling-rate 100]
  ```

说明：
- `--config` 为 JSON 配置文件路径，默认 `config/config.json`。
- 若未提供 `--robot-sn`，将从配置 `robot.robot_sn` 读取。

## 配置文件示例
`config/config.json` 示例（请根据实际调整）：

```json
{
  "robot": {
    "robot_sn": "Rizon4s-123456"
  },
  "collection": {
    "duration": 10,
    "sampling_rate": 100
  }
}
```

## 兼容性与注意事项
- 为保证 `--help` 可用，CLI 采用惰性导入，只有在执行子命令时才加载依赖模块。
- 运行业务命令需确保 `flexivrdk` 可用且机器人连接正常。
- 旧入口脚本如 `src/business/rdk_Programs/main.py` 保留但不再推荐，建议改用统一 CLI。

## 后续计划（可选）
- 整理 `test/example_py` 中脚本为统一子命令或文档链接。
- 为 `src/business/PP_Programs` 添加合适的 CLI 子命令封装。
