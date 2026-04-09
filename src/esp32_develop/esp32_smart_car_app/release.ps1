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

# 4. 更新 version.json (保持固件信息不变)
Write-Host ">>> 正在更新 version.json..." -ForegroundColor Cyan
$localJsonPath = "./ota_updates/version.json"

if (Test-Path $localJsonPath) {
    # 读取现有 JSON
    $jsonObj = Get-Content $localJsonPath -Raw | ConvertFrom-Json
    
    # 更新 App 部分
    if (-not $jsonObj.app) { $jsonObj | Add-Member -MemberType NoteProperty -Name "app" -Value @{} }
    $jsonObj.app.version = $Version
    $jsonObj.app.build_number = $newBuildNumber
    $jsonObj.app.url = "https://github.com/Wann-99/esp32_smart_car_updates/releases/latest/download/app-release.apk"
    $jsonObj.app.changelog = $Changelog
    $jsonObj.app.sha256 = $hash
    $jsonObj.app.min_version = "1.0.0"

    # 写回文件 (使用 4 层深度以确保嵌套对象正确序列化)
    $jsonObj | ConvertTo-Json -Depth 4 | Set-Content $localJsonPath
    Write-Host ">>> 离线元数据已同步！($localJsonPath)" -ForegroundColor Green

    Write-Host "`n>>> [提示] 请手动执行 Git 操作以发布元数据：" -ForegroundColor Yellow
    Write-Host "    cd ota_updates"
    Write-Host "    git add version.json"
    Write-Host "    git commit -m `"release: v$Version (build $newBuildNumber)`""
    Write-Host "    git push"
} else {
    Write-Host "!!! 未找到 ./ota_updates/version.json，请确保该文件夹和文件存在。" -ForegroundColor Yellow
}

Write-Host "`n====================================================" -ForegroundColor Magenta
Write-Host "流程结束！请手动执行以下步骤完成发布：" -ForegroundColor Magenta
Write-Host "1. 将 $apkPath 上传到 GitHub Release"
Write-Host "2. (见上方提示) 推送 ota_updates 目录下的 version.json"
Write-Host "====================================================`n"
