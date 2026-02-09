// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'RoboCar-A';

  @override
  String get mine => '我的';

  @override
  String get deviceSettings => '设备设置';

  @override
  String get networkConfig => '网络配置';

  @override
  String get aboutRoboCar => '关于 RoboCar-A';

  @override
  String get logs => '日志记录';

  @override
  String get statistics => '使用统计';

  @override
  String get logout => '退出登录';

  @override
  String get admin => '管理员';

  @override
  String get id => 'ID';

  @override
  String get unbound => '未绑定';

  @override
  String get language => '语言切换';

  @override
  String get chinese => '简体中文';

  @override
  String get english => '英文';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get networkSettings => '网络设置';

  @override
  String get carIpAddress => '小车 IP 地址';

  @override
  String get cameraIpAddress => '摄像头 IP 地址';

  @override
  String get discoveredDevices => '发现的设备';

  @override
  String get motionSettings => '运动设置';

  @override
  String get maxSpeed => '最大速度';

  @override
  String get patrolSpeed => '巡逻速度';

  @override
  String get obstacleSensitivity => '避障灵敏度';

  @override
  String get rechargeThreshold => '回充阈值';

  @override
  String get visionSettings => '视觉设置';

  @override
  String get videoResolution => '视频分辨率';

  @override
  String get nightMode => '夜视模式';

  @override
  String get aiDetection => 'AI检测';

  @override
  String get detectionSensitivity => '检测灵敏度';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get firmwareUpdateOnline => '固件升级 (在线)';

  @override
  String get firmwareUpdateLocal => '固件升级 (本地推送)';

  @override
  String get factoryReset => '恢复出厂设置';

  @override
  String get rebootDevice => '重启设备';

  @override
  String get exportLogs => '导出日志';

  @override
  String get distance => '距离';

  @override
  String get mode => '模式';

  @override
  String get manual => '手动';

  @override
  String get auto => '自动';

  @override
  String get high => '高';

  @override
  String get medium => '中';

  @override
  String get low => '低';

  @override
  String get on => '开';

  @override
  String get off => '关';

  @override
  String get person => '人形';

  @override
  String get pet => '宠物';

  @override
  String get all => '全部';

  @override
  String get confirm => '确定';

  @override
  String get cancel => '取消';

  @override
  String get rebootConfirm => '确定要重启小车吗？';

  @override
  String get factoryResetConfirm => '确定要恢复出厂设置吗？这将重置所有 network 和 motion 配置。';

  @override
  String get factoryResetSuccess => '设备已恢复出厂设置，请手动重启设备以使配置完全生效。';

  @override
  String newFirmwareFound(String version) {
    return '发现新固件 v$version';
  }

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get snapshotSaved => '快照已保存！';

  @override
  String error(String message) {
    return '错误: $message';
  }

  @override
  String get deviceOnline => '设备在线';

  @override
  String get deviceOffline => '设备离线';

  @override
  String get connectionNormal => '连接正常，可以开始控制';

  @override
  String get pleaseConnect => '请连接设备以开始使用';

  @override
  String get connectDevice => '连接设备';

  @override
  String get disconnectDevice => '断开连接';

  @override
  String get connectionFailed => '连接失败，请检查设备 IP 和网络';

  @override
  String get battery => '电量';

  @override
  String get signal => '信号';

  @override
  String version(String v) {
    return '版本 $v';
  }

  @override
  String get features => '功能介绍';

  @override
  String get realtimeControl => '实时遥控';

  @override
  String get realtimeControlDesc => '支持通过移动网络或局域网对小车进行低延迟实时控制。';

  @override
  String get hdVideo => '高清图传';

  @override
  String get hdVideoDesc => '内置高清摄像头，实时传输第一视角画面。';

  @override
  String get autoNav => '自动导航';

  @override
  String get autoNavDesc => '基于多传感器融合，实现精准的路径规划与自主避障。';

  @override
  String get aiVision => 'AI 视觉';

  @override
  String get aiVisionDesc => '集成人形识别、手势控制等多种 AI 视觉算法。';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get newVersionAvailable => '发现新版本可用';

  @override
  String get latestVersion => '当前已是最新版本';

  @override
  String get updateContent => '更新内容:';

  @override
  String get later => '稍后';

  @override
  String get downloadNow => '立即下载';

  @override
  String get downloading => '正在下载更新包...';

  @override
  String newAppVersionFound(String version) {
    return '发现新版本 v$version';
  }

  @override
  String get login => '登录';

  @override
  String get register => '注册';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get enterUsername => '请输入用户名';

  @override
  String get enterPassword => '密码长度至少为 6 位';

  @override
  String get invalidCredentials => '用户名或密码错误';

  @override
  String get regDisabled => '演示版本暂不支持注册';

  @override
  String get dontHaveAccount => '没有账号？点击注册';

  @override
  String get alreadyHaveAccount => '已有账号？点击登录';

  @override
  String get charging => '充电中';

  @override
  String get patrolling => '巡逻中';

  @override
  String get alarm => '警报';

  @override
  String get pleaseConnectFirst => '请先连接设备';

  @override
  String get rebooting => '重启指令已发送';

  @override
  String get factoryResetTitle => '重置成功';

  @override
  String get gotIt => '我知道了';

  @override
  String get sendingConfig => '正在发送配置...';

  @override
  String get wifiConfigSuccess => '配置成功！设备正在重启...';

  @override
  String wifiConfigFailed(String status) {
    return '配置失败: $status';
  }

  @override
  String get wifiConfigTip => '如果尚未连接，请先连接到 \'RoboCar-A-Config\' WiFi。';

  @override
  String get deviceIpDefault => '设备 IP (默认: 192.168.4.1)';

  @override
  String get wifiSsid => 'WiFi 名称 (SSID)';

  @override
  String get wifiPassword => 'WiFi 密码';

  @override
  String get home => '首页';

  @override
  String get navigation => '导航';

  @override
  String get control => '控制';

  @override
  String get navDeveloping => '导航功能开发中...';

  @override
  String get connectWarning => '连接警告';

  @override
  String get offlineWarning => '当前设备处于离线状态，请先在首页连接设备后再开始控制。';

  @override
  String get startControl => '开始控制';

  @override
  String get updateNote => '注意：升级过程中请勿断电或断开网络连接。';

  @override
  String get otaCommandSent => 'OTA 指令已发送';

  @override
  String localOtaConfirm(String file, String size) {
    return '确定进行本地固件升级吗？\n文件：$file\n大小：$size MB\n\n注意：请确保手机和设备处于同一 WiFi 网络。';
  }

  @override
  String get localOtaStarted => '本地 OTA 已启动';

  @override
  String get running => '运行中';

  @override
  String get selectFile => '选择文件';

  @override
  String get batteryLow => '电量<20%';
}
