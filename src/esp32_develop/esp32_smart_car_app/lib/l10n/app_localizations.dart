import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'RoboCar-A'**
  String get appTitle;

  /// No description provided for @mine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get mine;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get deviceSettings;

  /// No description provided for @networkConfig.
  ///
  /// In en, this message translates to:
  /// **'Network Config'**
  String get networkConfig;

  /// No description provided for @aboutRoboCar.
  ///
  /// In en, this message translates to:
  /// **'About RoboCar-A'**
  String get aboutRoboCar;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @unbound.
  ///
  /// In en, this message translates to:
  /// **'Unbound'**
  String get unbound;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network Settings'**
  String get networkSettings;

  /// No description provided for @carIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Car IP Address'**
  String get carIpAddress;

  /// No description provided for @cameraIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Camera IP Address'**
  String get cameraIpAddress;

  /// No description provided for @discoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered Devices'**
  String get discoveredDevices;

  /// No description provided for @motionSettings.
  ///
  /// In en, this message translates to:
  /// **'Motion Settings'**
  String get motionSettings;

  /// No description provided for @maxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// No description provided for @patrolSpeed.
  ///
  /// In en, this message translates to:
  /// **'Patrol Speed'**
  String get patrolSpeed;

  /// No description provided for @obstacleSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Obstacle Sensitivity'**
  String get obstacleSensitivity;

  /// No description provided for @rechargeThreshold.
  ///
  /// In en, this message translates to:
  /// **'Recharge Threshold'**
  String get rechargeThreshold;

  /// No description provided for @visionSettings.
  ///
  /// In en, this message translates to:
  /// **'Vision Settings'**
  String get visionSettings;

  /// No description provided for @videoResolution.
  ///
  /// In en, this message translates to:
  /// **'Video Resolution'**
  String get videoResolution;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get nightMode;

  /// No description provided for @aiDetection.
  ///
  /// In en, this message translates to:
  /// **'AI Detection'**
  String get aiDetection;

  /// No description provided for @detectionSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Detection Sensitivity'**
  String get detectionSensitivity;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @firmwareUpdateOnline.
  ///
  /// In en, this message translates to:
  /// **'Firmware Update (Online)'**
  String get firmwareUpdateOnline;

  /// No description provided for @firmwareUpdateLocal.
  ///
  /// In en, this message translates to:
  /// **'Firmware Update (Local)'**
  String get firmwareUpdateLocal;

  /// No description provided for @factoryReset.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset'**
  String get factoryReset;

  /// No description provided for @rebootDevice.
  ///
  /// In en, this message translates to:
  /// **'Reboot Device'**
  String get rebootDevice;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get exportLogs;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get manual;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get auto;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @pet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get pet;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @rebootConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reboot the car?'**
  String get rebootConfirm;

  /// No description provided for @factoryResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to factory reset? This will reset all network and motion configurations.'**
  String get factoryResetConfirm;

  /// No description provided for @factoryResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Factory reset successful. Please manually reboot the device to take full effect.'**
  String get factoryResetSuccess;

  /// No description provided for @newFirmwareFound.
  ///
  /// In en, this message translates to:
  /// **'New firmware found v{version}'**
  String newFirmwareFound(String version);

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @snapshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Snapshot Saved!'**
  String get snapshotSaved;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error(String message);

  /// No description provided for @deviceOnline.
  ///
  /// In en, this message translates to:
  /// **'Device Online'**
  String get deviceOnline;

  /// No description provided for @deviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Device Offline'**
  String get deviceOffline;

  /// No description provided for @connectionNormal.
  ///
  /// In en, this message translates to:
  /// **'Connection normal, ready to control'**
  String get connectionNormal;

  /// No description provided for @pleaseConnect.
  ///
  /// In en, this message translates to:
  /// **'Please connect device to start'**
  String get pleaseConnect;

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect Device'**
  String get connectDevice;

  /// No description provided for @disconnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectDevice;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, please check IP and network'**
  String get connectionFailed;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {v}'**
  String version(String v);

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @realtimeControl.
  ///
  /// In en, this message translates to:
  /// **'Real-time Control'**
  String get realtimeControl;

  /// No description provided for @realtimeControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Low-latency control via network.'**
  String get realtimeControlDesc;

  /// No description provided for @hdVideo.
  ///
  /// In en, this message translates to:
  /// **'HD Video'**
  String get hdVideo;

  /// No description provided for @hdVideoDesc.
  ///
  /// In en, this message translates to:
  /// **'First-person view transmission.'**
  String get hdVideoDesc;

  /// No description provided for @autoNav.
  ///
  /// In en, this message translates to:
  /// **'Auto Navigation'**
  String get autoNav;

  /// No description provided for @autoNavDesc.
  ///
  /// In en, this message translates to:
  /// **'Autonomous obstacle avoidance.'**
  String get autoNavDesc;

  /// No description provided for @aiVision.
  ///
  /// In en, this message translates to:
  /// **'AI Vision'**
  String get aiVision;

  /// No description provided for @aiVisionDesc.
  ///
  /// In en, this message translates to:
  /// **'Human recognition and AI algorithms.'**
  String get aiVisionDesc;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdate;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Already the latest version'**
  String get latestVersion;

  /// No description provided for @updateContent.
  ///
  /// In en, this message translates to:
  /// **'Update Content:'**
  String get updateContent;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download Now'**
  String get downloadNow;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update package...'**
  String get downloading;

  /// No description provided for @newAppVersionFound.
  ///
  /// In en, this message translates to:
  /// **'New version v{version} found'**
  String newAppVersionFound(String version);

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get register;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get enterUsername;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get enterPassword;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidCredentials;

  /// No description provided for @regDisabled.
  ///
  /// In en, this message translates to:
  /// **'Registration disabled in demo version'**
  String get regDisabled;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// No description provided for @charging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get charging;

  /// No description provided for @patrolling.
  ///
  /// In en, this message translates to:
  /// **'Patrolling'**
  String get patrolling;

  /// No description provided for @alarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarm;

  /// No description provided for @pleaseConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Please connect device first'**
  String get pleaseConnectFirst;

  /// No description provided for @rebooting.
  ///
  /// In en, this message translates to:
  /// **'Reboot command sent'**
  String get rebooting;

  /// No description provided for @factoryResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Success'**
  String get factoryResetTitle;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @sendingConfig.
  ///
  /// In en, this message translates to:
  /// **'Sending configuration...'**
  String get sendingConfig;

  /// No description provided for @wifiConfigSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success! Device restarting...'**
  String get wifiConfigSuccess;

  /// No description provided for @wifiConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {status}'**
  String wifiConfigFailed(String status);

  /// No description provided for @wifiConfigTip.
  ///
  /// In en, this message translates to:
  /// **'Connect to \'RoboCar-A-Config\' WiFi if not already connected.'**
  String get wifiConfigTip;

  /// No description provided for @deviceIpDefault.
  ///
  /// In en, this message translates to:
  /// **'Device IP (Default: 192.168.4.1)'**
  String get deviceIpDefault;

  /// No description provided for @wifiSsid.
  ///
  /// In en, this message translates to:
  /// **'WiFi SSID'**
  String get wifiSsid;

  /// No description provided for @wifiPassword.
  ///
  /// In en, this message translates to:
  /// **'WiFi Password'**
  String get wifiPassword;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @control.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get control;

  /// No description provided for @navDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Navigation feature under development...'**
  String get navDeveloping;

  /// No description provided for @connectWarning.
  ///
  /// In en, this message translates to:
  /// **'Connection Warning'**
  String get connectWarning;

  /// No description provided for @offlineWarning.
  ///
  /// In en, this message translates to:
  /// **'Device is offline. Please connect on Home page before control.'**
  String get offlineWarning;

  /// No description provided for @startControl.
  ///
  /// In en, this message translates to:
  /// **'Start Control'**
  String get startControl;

  /// No description provided for @updateNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Do not power off or disconnect network during update.'**
  String get updateNote;

  /// No description provided for @otaCommandSent.
  ///
  /// In en, this message translates to:
  /// **'OTA command sent'**
  String get otaCommandSent;

  /// No description provided for @localOtaConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm local firmware update?\nFile: {file}\nSize: {size} MB\n\nNote: Ensure phone and device are on same WiFi.'**
  String localOtaConfirm(String file, String size);

  /// No description provided for @localOtaStarted.
  ///
  /// In en, this message translates to:
  /// **'Local OTA started'**
  String get localOtaStarted;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @batteryLow.
  ///
  /// In en, this message translates to:
  /// **'Battery<20%'**
  String get batteryLow;

  /// No description provided for @remoteControlSettings.
  ///
  /// In en, this message translates to:
  /// **'Remote Control Settings'**
  String get remoteControlSettings;

  /// No description provided for @remoteMode.
  ///
  /// In en, this message translates to:
  /// **'Remote Mode'**
  String get remoteMode;

  /// No description provided for @relayServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Relay Server Address'**
  String get relayServerAddress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
