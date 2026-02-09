# ESP32-S3 Smart Car - Espressif-IDE Guide (最新版)

## 1. 导入项目 (Import Project)
1. 打开 **Espressif-IDE**。
2. 点击菜单栏的 **File** -> **Import...**。
3. 在弹窗中展开 **乐鑫 (Espressif)** 文件夹，选择 **Existing IDF Project**，点击 **Next**。
4. 在 **Import Location** (Root Directory) 点击 **Browse...**。
5. 选择本目录：
   `d:\PythonDevelop\Projects\PycharmProjects\flexivrobot\esp32_smart_car_app\firmware\esp32_smart_car_idf`
6. 点击 **Finish**。

## 2. 设置目标芯片 (Set Target)
**注意：请使用顶部工具栏进行切换**
1. 观察 IDE 顶部工具栏（右上角区域）。
2. 你会看到一个下拉框，当前可能显示为 `esp32` 或 `esp32p4` (如你截图中所示)。
3. **点击这个下拉框**。
4. 选择 **New Launch Target** (或者 **Edit Launch Target**)。
5. 在弹出的窗口中：
   - **Target**: 选择 `esp32s3`。
   - **Serial Port**: 选择你连接的开发板串口 (如 COM3, COM5)。
   - 点击 **Finish** / **OK**。
6. 此时下拉框应显示为 `esp32s3`。

## 3. 配置 Wi-Fi (Menu Config)
1. 在左侧 **Project Explorer** 中，右键点击项目 `esp32_smart_car_idf`。
2. 选择 **ESP-IDF** -> **Menu Config** (在菜单最下方)。
   *(或者点击顶部工具栏上的 齿轮图标)*
3. 等待配置界面加载。
4. 在左侧菜单找到 **Smart Car Configuration**。
   - 修改 **WiFi SSID** (默认 `Tenda_WLAN`)
   - 修改 **WiFi Password** (默认 `Wj_990518.`)
5. 点击 **Save** 保存。

## 4. 编译与烧录 (Build & Flash)
1. **编译**: 点击顶部工具栏的 **锤子图标** (Build)。
2. **烧录**: 确保顶部下拉框是 `esp32s3`，然后点击 **播放图标** (Run)。

## 5. 常见问题
- **找不到 Menu Config**: 请确保你已经成功导入项目，并且在右键菜单的 `ESP-IDF` 子菜单最底部查找。
- **I2C 引脚冲突**: 检查 `main/pca9685.h` 中的 `I2C_MASTER_SDA_IO` 和 `SCL`。
