import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone for scheduled notifications
    tz.initializeTimeZones();
    final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
    final String currentTimeZone = tzInfo.identifier;
    try {
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (_) {}
    print('Timezone initialized to: $currentTimeZone');

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize plugin
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  // Request permissions (primarily for iOS/Android 13+)
  Future<void> requestPermissions() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final canExact = await android?.canScheduleExactNotifications();
    if (canExact == false) {
      await android?.requestExactAlarmsPermission();
    }

    final ios = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Schedule a daily repeating notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int second,
  }) async {
    print('Scheduling notification for $hour:$minute:$second');

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasExactAlarm = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      print('Has exact alarm permission: $hasExactAlarm');
      if (hasExactAlarm == false) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute, second),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel_id',
          'Habit Reminders',
          channelDescription: 'Notifications for habit reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time, // This makes it repeat daily at the same time
    );
  }

  /// 单次定时提醒（不重复）。用于多次打卡的「间隔提醒」链。
  Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledLocal,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime when = tz.TZDateTime(
      tz.local,
      scheduledLocal.year,
      scheduledLocal.month,
      scheduledLocal.day,
      scheduledLocal.hour,
      scheduledLocal.minute,
      scheduledLocal.second,
      scheduledLocal.millisecond,
    );
    if (!when.isAfter(now)) return;

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasExactAlarm = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      if (hasExactAlarm == false) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel_id',
          'Habit Reminders',
          channelDescription: 'Notifications for habit reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
    );
  }

  // Show immediate notification for testing
  Future<void> showTestNotification() async {
    await flutterLocalNotificationsPlugin.show(
      id: 999,
      title: '测试通知',
      body: '这是一条即时测试通知！如果你看到了，说明通知功能配置成功。',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel_id',
          'Habit Reminders',
          channelDescription: 'Notifications for habit reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Helper function to calculate the next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, int second) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, second);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    print('Scheduled raw time: $hour:$minute:$second. Next instance: $scheduledDate');
    return scheduledDate;
  }
}
