# RoboCar-A 固件（编码器闭环掉头版）

本固件是 `esp32_smart_car_app/firmware/esp32_smart_car_idf` 的**副本**，在其基础上**新增了基于电机编码器的闭环掉头/转向**功能。原项目未改动。

## 新增内容

### 1. 新指令 `turn`（编码器闭环原地转向）

```json
{"cmd": "turn", "angle": 180, "dir": 1}      // 转 180°，dir: 1=顺时针 / -1=逆时针
{"cmd": "turn", "counts": 10500, "dir": 1}   // 直接指定编码器脉冲数（用于校准，免重新烧录）
```

- 小车**原地旋转**，实时读取四个轮子的编码器脉冲，达到目标脉冲数后**精确停止**。
- 不受电量/地面摩擦影响，比按时间旋转准得多。
- 任意 `move` 指令或 `motor_stop()` 会**立即取消**正在进行的掉头（手动接管）。

### 2. 改动的文件

| 文件 | 改动 |
|------|------|
| `main/motor_driver.h` | 新增 `motor_turn_angle / motor_turn_counts / motor_turn_active / motor_turn_cancel` 声明；引入 `<stdbool.h>` |
| `main/motor_driver.c` | 新增掉头状态机：控制任务中按编码器进度驱动原地旋转并到点停止；`move_car`/`motor_stop` 中取消掉头 |
| `main/car_commands.c` | 新增 `turn` 指令解析 |

### 3. 可调参数（在 `motor_driver.c` 顶部）

```c
#define TURN_SPEED_CPI       120     // 掉头转速（每 50ms 控制周期的目标脉冲数，越大越快、过冲略增）
#define TURN_COUNTS_PER_360  21000   // 整圈 360° 的平均脉冲数（angle 模式用；可被指令里的 counts 覆盖）
```

## 校准方法（推荐，免重新烧录）

固件已支持指令里直接传 `counts`，所以网页端可以**实时校准**，不用每次改常量重烧：

1. 网页 →「设备管理」→「掉头校准」
2. 点「测试掉头」，看转了多少
3. 转过头就**减小**脉冲数，没转够就**增大**，再测，直到正好 180°
4. 点「保存」。之后「一键掉头」就用这个值。

> 默认 180° = 10500 脉冲（即 `TURN_COUNTS_PER_360 / 2`）。该估算基于轮径 60mm、4200 脉冲/圈
> 及典型轮距，**实际值因车而异，务必现场校准**。

## 编译与烧录（ESP-IDF）

需要 ESP-IDF 环境（与原项目相同，目标芯片 ESP32-S3）：

```bash
cd esp32_smart_car_idf
idf.py set-target esp32s3      # 首次
idf.py build
idf.py -p <串口> flash monitor
```

> `build/`、`managed_components/`、`sdkconfig` 等生成物未一并复制，首次 `idf.py build`
> 会自动重新生成（依赖见 `dependencies.lock` / `main/idf_component.yml`）。
