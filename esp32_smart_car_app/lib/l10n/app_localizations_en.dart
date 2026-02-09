// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RoboCar-A';

  @override
  String get mine => 'Mine';

  @override
  String get deviceSettings => 'Device Settings';

  @override
  String get networkConfig => 'Network Config';

  @override
  String get aboutRoboCar => 'About RoboCar-A';

  @override
  String get logs => 'Logs';

  @override
  String get statistics => 'Statistics';

  @override
  String get logout => 'Logout';

  @override
  String get admin => 'Admin';

  @override
  String get id => 'ID';

  @override
  String get unbound => 'Unbound';

  @override
  String get language => 'Language';

  @override
  String get chinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get networkSettings => 'Network Settings';

  @override
  String get carIpAddress => 'Car IP Address';

  @override
  String get cameraIpAddress => 'Camera IP Address';

  @override
  String get discoveredDevices => 'Discovered Devices';

  @override
  String get motionSettings => 'Motion Settings';

  @override
  String get maxSpeed => 'Max Speed';

  @override
  String get patrolSpeed => 'Patrol Speed';

  @override
  String get obstacleSensitivity => 'Obstacle Sensitivity';

  @override
  String get rechargeThreshold => 'Recharge Threshold';

  @override
  String get visionSettings => 'Vision Settings';

  @override
  String get videoResolution => 'Video Resolution';

  @override
  String get nightMode => 'Night Mode';

  @override
  String get aiDetection => 'AI Detection';

  @override
  String get detectionSensitivity => 'Detection Sensitivity';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get firmwareUpdateOnline => 'Firmware Update (Online)';

  @override
  String get firmwareUpdateLocal => 'Firmware Update (Local)';

  @override
  String get factoryReset => 'Factory Reset';

  @override
  String get rebootDevice => 'Reboot Device';

  @override
  String get exportLogs => 'Export Logs';

  @override
  String get distance => 'Distance';

  @override
  String get mode => 'Mode';

  @override
  String get manual => 'MANUAL';

  @override
  String get auto => 'AUTO';

  @override
  String get high => 'High';

  @override
  String get medium => 'Medium';

  @override
  String get low => 'Low';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get person => 'Person';

  @override
  String get pet => 'Pet';

  @override
  String get all => 'All';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get rebootConfirm => 'Are you sure you want to reboot the car?';

  @override
  String get factoryResetConfirm =>
      'Are you sure you want to factory reset? This will reset all network and motion configurations.';

  @override
  String get factoryResetSuccess =>
      'Factory reset successful. Please manually reboot the device to take full effect.';

  @override
  String newFirmwareFound(String version) {
    return 'New firmware found v$version';
  }

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get snapshotSaved => 'Snapshot Saved!';

  @override
  String error(String message) {
    return 'Error: $message';
  }

  @override
  String get deviceOnline => 'Device Online';

  @override
  String get deviceOffline => 'Device Offline';

  @override
  String get connectionNormal => 'Connection normal, ready to control';

  @override
  String get pleaseConnect => 'Please connect device to start';

  @override
  String get connectDevice => 'Connect Device';

  @override
  String get disconnectDevice => 'Disconnect';

  @override
  String get connectionFailed =>
      'Connection failed, please check IP and network';

  @override
  String get battery => 'Battery';

  @override
  String get signal => 'Signal';

  @override
  String version(String v) {
    return 'Version $v';
  }

  @override
  String get features => 'Features';

  @override
  String get realtimeControl => 'Real-time Control';

  @override
  String get realtimeControlDesc => 'Low-latency control via network.';

  @override
  String get hdVideo => 'HD Video';

  @override
  String get hdVideoDesc => 'First-person view transmission.';

  @override
  String get autoNav => 'Auto Navigation';

  @override
  String get autoNavDesc => 'Autonomous obstacle avoidance.';

  @override
  String get aiVision => 'AI Vision';

  @override
  String get aiVisionDesc => 'Human recognition and AI algorithms.';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String get latestVersion => 'Already the latest version';

  @override
  String get updateContent => 'Update Content:';

  @override
  String get later => 'Later';

  @override
  String get downloadNow => 'Download Now';

  @override
  String get downloading => 'Downloading update package...';

  @override
  String newAppVersionFound(String version) {
    return 'New version v$version found';
  }

  @override
  String get login => 'LOG IN';

  @override
  String get register => 'SIGN UP';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get enterUsername => 'Please enter username';

  @override
  String get enterPassword => 'Password must be at least 6 characters';

  @override
  String get invalidCredentials => 'Invalid username or password';

  @override
  String get regDisabled => 'Registration disabled in demo version';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get charging => 'Charging';

  @override
  String get patrolling => 'Patrolling';

  @override
  String get alarm => 'Alarm';

  @override
  String get pleaseConnectFirst => 'Please connect device first';

  @override
  String get rebooting => 'Reboot command sent';

  @override
  String get factoryResetTitle => 'Reset Success';

  @override
  String get gotIt => 'Got it';

  @override
  String get sendingConfig => 'Sending configuration...';

  @override
  String get wifiConfigSuccess => 'Success! Device restarting...';

  @override
  String wifiConfigFailed(String status) {
    return 'Failed: $status';
  }

  @override
  String get wifiConfigTip =>
      'Connect to \'RoboCar-A-Config\' WiFi if not already connected.';

  @override
  String get deviceIpDefault => 'Device IP (Default: 192.168.4.1)';

  @override
  String get wifiSsid => 'WiFi SSID';

  @override
  String get wifiPassword => 'WiFi Password';

  @override
  String get home => 'Home';

  @override
  String get navigation => 'Navigation';

  @override
  String get control => 'Control';

  @override
  String get navDeveloping => 'Navigation feature under development...';

  @override
  String get connectWarning => 'Connection Warning';

  @override
  String get offlineWarning =>
      'Device is offline. Please connect on Home page before control.';

  @override
  String get startControl => 'Start Control';

  @override
  String get updateNote =>
      'Note: Do not power off or disconnect network during update.';

  @override
  String get otaCommandSent => 'OTA command sent';

  @override
  String localOtaConfirm(String file, String size) {
    return 'Confirm local firmware update?\nFile: $file\nSize: $size MB\n\nNote: Ensure phone and device are on same WiFi.';
  }

  @override
  String get localOtaStarted => 'Local OTA started';

  @override
  String get running => 'Running';

  @override
  String get selectFile => 'Select File';

  @override
  String get batteryLow => 'Battery<20%';
}
