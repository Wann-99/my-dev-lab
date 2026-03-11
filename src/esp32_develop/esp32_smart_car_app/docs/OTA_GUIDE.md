# 智能小车 OTA 升级系统指南

本指南详细说明了如何配置、发布及维护 RoboCar-A 的 App 与固件升级系统。

## 一、 系统架构

本系统采用 **云端元数据驱动** 的架构，通过 GitHub 托管配置文件，jsDelivr CDN 提供加速。

### 1.1 核心链路
`version.json (云端)` → `移动端 App (Flutter)` → `ESP32 主控/摄像头 (OTA)`

### 1.2 关键特性
- **SHA256 校验**: 确保文件下载完整性与安全性。
- **8KB 分块传输**: 降低 ESP32 内存压力，提升 OTA 成功率。
- **Header 目标校验**: 自动识别固件目标 MCU（Main 或 Camera），防止错发。
- **强制更新控制**: 支持设置最低版本要求（`min_version`）。

---

## 二、 自动化发版流程 (Recommended)

项目根目录下提供了一个 `release.ps1` PowerShell 脚本，可一键完成版本递增、编译、哈希计算及元数据推送。

### 1. 运行环境准备
确保您的 PowerShell 允许运行脚本（仅需执行一次）：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. 执行发版脚本
- **发布新版本**（例如 v2.1.0）：
  ```powershell
  .\release.ps1 -Version "2.1.0" -Changelog "优化了UI和P2P连接"
  ```
- **仅发布小补丁**（保持当前版本名，仅递增内部 Build Number）：
  ```powershell
  .\release.ps1
  ```

### 3. 脚本自动化内容
脚本会自动执行以下操作：
1. **自动递增** `pubspec.yaml` 中的 `version`（例如 `2.0.0+7` -> `2.0.0+8`）。
2. **自动编译** 生成 Release APK。
3. **自动计算** 生成文件的 SHA256 哈希值。
4. **自动更新** `./ota_updates/version.json` 文件。
5. **自动推送** 将 `version.json` 更改提交并推送到 GitHub 仓库。

### 4. 手动完成最后一步
脚本运行结束后，您只需：
1. 访问 GitHub 仓库的 **Releases** 页面。
2. 创建或编辑对应的 Release（如 `v2.1.0`）。
3. 将本地生成的 `./build/app/outputs/flutter-apk/app-release.apk` 上传至附件。
   - **注意**：文件名必须保持为 `app-release.apk`。

---

## 三、 手动发版流程 (Manual Flow)

如果您需要手动执行某些步骤，请参考以下指南：

### 1. 目录结构
版本元数据文件位于：`./ota_updates/version.json`。App 会从该路径的 Raw 链接读取更新。

### 2. 修改本地项目配置
在 `pubspec.yaml` 中更新版本号（必须确保 `+` 后的数字递增）。

### 3. 编译并生成校验值
```powershell
flutter build apk --release --no-tree-shake-icons
Get-FileHash ./build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256 | Format-List
```

### 4. 同步元数据
更新 `ota_updates/version.json` 中的 `version`、`build_number`、`sha256` 和 `changelog`。

---

## 四、 常见问题排查 (Troubleshooting)

### Q: 更新后为什么还提示有新版本？
- **原因**：App 内部读取到的版本号比 `version.json` 里的版本号小。
- **检查**：确认打包前是否修改了 `pubspec.yaml`。在 App 调试模式下观察日志：`Update Check - Current: [内部版本], Latest: [云端版本]`。

### Q: 下载完成后提示“校验失败”？
- **原因**：`version.json` 里的 `sha256` 与下载下来的文件哈希值不一致。
- **解决**：重新运行 PowerShell 命令计算哈希，并确保 JSON 中没有多余的空格或不可见字符。

### Q: 下载到 100% 后没有弹出安装界面？
- **原因**：可能是 Android 权限未授予或 APK 签名冲突（Debug 版无法直接覆盖 Release 版）。
- **解决**：先手动卸载旧版，再重新通过 App 下载安装。如果是正式发布，请确保使用相同的签名文件打包。


---

## 三、 配置项详解

| 字段 | 说明 |
| :--- | :--- |
| `version` | 最新版本号（格式如 `1.0.0`）。 |
| `url` | 文件的直接下载地址。建议使用 jsDelivr 加速。 |
| `sha256` | 文件的 SHA256 校验值（不区分大小写）。 |
| `min_version` | **最低可用版本**。若 App/设备当前版本低于此值，将强制更新。 |
| `changelog` | 更新日志，支持 `\n` 换行。 |

---

## 四、 开发者模式（本地 OTA）

如果您想通过本地文件直接升级而不通过云端：
1. 进入 App 的 **“我的 -> 更多设置 -> 高级设置”**。
2. 点击 **“本地固件升级”**。
3. 选择手机中的 `.bin` 文件。
4. **识别逻辑**: 
   - App 会读取文件 Header。若包含 `TARGET:CAM` 则识别为摄像头，否则默认为主控。
   - 若 Header 校验通过，App 将启动本地 Web Server 并通知 ESP32 开始拉取。

---

## 五、 维护建议

1. **版本一致性**: 确保 `version.json` 中的版本号与固件内部定义的版本号一致，否则 App 升级成功后仍会提示有新版本。
2. **CDN 刷新**: 如果您更新了 GitHub 上的文件但链接没变，jsDelivr 可能会有缓存。App 已通过时间戳（`?t=...`）抑制了 `version.json` 的缓存，但下载大文件时仍需注意 CDN 同步情况。
3. **安全提醒**: 严禁关闭 SHA256 校验，这是防止固件损坏导致设备无法启动的最后一道防线。
