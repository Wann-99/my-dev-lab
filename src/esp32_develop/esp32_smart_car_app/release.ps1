# RoboCar-A 一键发版脚本 (Release Automation Script)
# 用法: .\release.ps1 -Version "2.0.1" -Changelog "优化了UI和P2P连接"

param (
    [string]$Version,
    [string]$Changelog = "常规更新与性能优化"
)

$ErrorActionPreference = "Stop"

# 1. 自动获取并递增内部版本号
Write-Host ">>> 正在解析 pubspec.yaml..." -ForegroundColor Cyan
$pubspecPath = "./pubspec.yaml"
$content = Get-Content $pubspecPath -Raw
$currentFullVersion = ([regex]'version: (\d+\.\d+\.\d+)\+(\d+)').Match($content)

if (-not $Version) {
    $Version = $currentFullVersion.Groups[1].Value
    Write-Host "未指定版本号，将保持当前版本名: $Version" -ForegroundColor Yellow
}

$newBuildNumber = [int]$currentFullVersion.Groups[2].Value + 1
$newVersionStr = "$Version+$newBuildNumber"

Write-Host ">>> 更新版本至: $newVersionStr" -ForegroundColor Green
$newContent = $content -replace 'version: \d+\.\d+\.\d+\+\d+', "version: $newVersionStr"
Set-Content $pubspecPath $newContent

# 2. 编译 Release APK
Write-Host ">>> 正在编译 APK (Release)..." -ForegroundColor Cyan
flutter build apk --release --no-tree-shake-icons

# 3. 计算 SHA256
$apkPath = "./build/app/outputs/flutter-apk/app-release.apk"
Write-Host ">>> 正在计算 SHA256..." -ForegroundColor Cyan
$hash = (Get-FileHash $apkPath -Algorithm SHA256).Hash.ToLower()
Write-Host "SHA256: $hash" -ForegroundColor Gray

# 4. 准备 version.json 内容
Write-Host ">>> 准备更新 version.json 建议内容..." -ForegroundColor Cyan
$jsonTemplate = @"
{
  "app": {
    "version": "$Version",
    "build_number": $newBuildNumber,
    "url": "https://github.com/Wann-99/esp32_smart_car_updates/releases/latest/download/app-release.apk",
    "changelog": "$Changelog",
    "sha256": "$hash",
    "min_version": "1.0.0"
  }
}
"@

# 自动更新本地的 version.json (如果存在)
$localJsonPath = "./ota_updates/version.json"
if (Test-Path $localJsonPath) {
    Set-Content $localJsonPath $jsonTemplate
    Write-Host ">>> 离线元数据已同步！($localJsonPath)" -ForegroundColor Green

    # 5. 自动执行 Git 提交与推送
    Write-Host ">>> 正在推送更新到 GitHub..." -ForegroundColor Cyan
    try {
        # 记录当前目录，进入 ota_updates 目录执行 git 操作
        # 这样即便 ota_updates 是一个独立的子模块或仓库也能正常工作
        $currentDir = Get-Location
        cd ota_updates
        
        git add version.json
        git commit -m "release: v$Version (build $newBuildNumber)"
        
        # 尝试推送并自动设置上游分支（解决首次推送失败问题）
        $pushResult = git push -u origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git Push Failed: $pushResult"
        }
        
        cd $currentDir
        Write-Host ">>> GitHub 元数据已成功推送！" -ForegroundColor Green
    } catch {
        cd $currentDir
        Write-Host "!!! Git 推送失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "提示: 请确保已在 ota_updates 目录运行过 git remote add origin <URL>" -ForegroundColor Yellow
    }
} else {
    Write-Host "!!! 未找到 ./ota_updates/version.json，请确保该文件夹和文件存在。" -ForegroundColor Yellow
}

Write-Host "`n====================================================" -ForegroundColor Magenta
Write-Host "流程结束！请手动执行最后一歨：" -ForegroundColor Magenta
Write-Host "将 $apkPath 上传到 GitHub Release"
Write-Host "====================================================`n"
