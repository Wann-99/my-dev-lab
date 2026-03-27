import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/models/habit_record.dart';
import 'package:space_time_plan_app/models/event_item.dart';
import 'package:space_time_plan_app/services/notification_service.dart';

class HabitProvider extends ChangeNotifier {
  List<HabitPlan> _habits = [];
  List<CheckInLog> _records = [];
  List<EventItem> _events = [];

  // 返回副本，防止外部（如 plan_view sort）直接污染内部列表顺序
  List<HabitPlan> get habits => List.of(_habits);
  List<CheckInLog> get records => _records;
  List<EventItem> get events => _events;

  CheckInLog? getHabitRecordForDate(int habitId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final idx = _records.indexWhere(
        (r) => r.habitId == habitId && r.date == normalizedDate);
    if (idx < 0) return null;
    return _records[idx];
  }

  void updateCheckInNote(int habitId, DateTime date, String? note) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final idx = _records.indexWhere(
        (r) => r.habitId == habitId && r.date == normalizedDate);
    if (idx < 0) return;
    _records[idx].note = note;
    _saveRecords();
    notifyListeners();
  }

  // Initialize and load data
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 先加载 Habits
    final String? habitsJson = prefs.getString('habits');
    if (habitsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(habitsJson);
        _habits = decoded.map((e) => HabitPlan.fromJson(e)).toList();
      } catch (e) {
        _habits = _generateInitialMockHabits();
        _saveHabits();
      }
    } else {
      _habits = _generateInitialMockHabits();
      _saveHabits();
    }

    // 2. 加载 Records
    final String? recordsJson = prefs.getString('records');
    if (recordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(recordsJson);
        _records = decoded.map((e) => CheckInLog.fromJson(e)).toList();
      } catch (e) {
        _records = [];
        _saveRecords();
      }
    }

    // 3. 加载 Events
    final String? eventsJson = prefs.getString('events');
    if (eventsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(eventsJson);
        _events = decoded.map((e) => EventItem.fromJson(e)).toList();
      } catch (e) {
        _events = [];
        _saveEvents();
      }
    }

    // 4. 所有数据加载完成后，再做每日自动恢复检查
    _checkAndAutoResetHabits();

    // 5. 为进行中的习惯恢复通知
    for (final habit in _habits) {
      if (habit.status != 2) {
        _scheduleNotificationForHabit(habit);
      }
    }
    
    notifyListeners();
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habits', jsonEncode(_habits.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('records', jsonEncode(_records.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('events', jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  // Add new habit
  void addHabit(HabitPlan habit) {
    _habits.add(habit);
    _saveHabits();
    _scheduleNotificationForHabit(habit);
    notifyListeners();
  }

  // Delete habit and its records
  void deleteHabit(int habitId) {
    _habits.removeWhere((h) => h.id == habitId);
    _records.removeWhere((r) => r.habitId == habitId);
    _saveHabits();
    _saveRecords();
    NotificationService().cancelNotification(habitId % 2147483647);
    notifyListeners();
  }

  // Update Habit Time
  void updateHabitTime(int habitId, String newTime) {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex >= 0) {
      _habits[habitIndex].timeOfDay = newTime;
      _saveHabits();
      notifyListeners();
    }
  }

  // Update Habit Details
  void updateHabitDetails(int habitId, {
    String? repeatType,
    List<int>? repeatDays,
    String? timeOfDay,
    DateTime? remindTime,
    DateTime? startDate,
  }) {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex >= 0) {
      if (repeatType != null) _habits[habitIndex].repeatType = repeatType;
      if (repeatDays != null) _habits[habitIndex].repeatDays = repeatDays;
      if (timeOfDay != null) _habits[habitIndex].timeOfDay = timeOfDay;
      if (remindTime != null) _habits[habitIndex].remindTime = remindTime;
      if (startDate != null) _habits[habitIndex].startDate = startDate;
      _saveHabits();
      _scheduleNotificationForHabit(_habits[habitIndex]);
      notifyListeners();
    }
  }

  /// 每日自动恢复检查：将昨日「今日已打卡」且设置了 autoReset 的习惯恢复为「进行中」
  void _checkAndAutoResetHabits() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    bool hasChanges = false;

    for (final habit in _habits) {
      // 只处理「今日已打卡」(status=1) 且设置了 autoReset 的习惯
      if (habit.status == 1 && habit.autoReset) {
        // 检查是否在昨天或更早完成的
        final completedDate = habit.completedDate;
        if (completedDate != null) {
          final completedDay = DateTime(completedDate.year, completedDate.month, completedDate.day);
          // 如果完成日期早于今天（即次日），则恢复为「进行中」继续打卡
          if (completedDay.isBefore(todayDate)) {
            habit.status = 0;
            habit.completedDate = null;
            hasChanges = true;
            // 恢复通知提醒
            _scheduleNotificationForHabit(habit);
          }
        }
      }
    }

    if (hasChanges) {
      _saveHabits();
    }
  }

  /// 习惯生命周期：0 进行中（今日未打卡）/ 1 今日已打卡 / 2 已暂停
  void setHabitStatus(int habitId, int status) {
    if (status < 0 || status > 2) return;
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex < 0) return;
    final habit = _habits[habitIndex];
    final oldStatus = habit.status;

    // 只有从「已暂停」恢复为「进行中」时，才清除当日打卡记录（恢复到初始状态）
    // 从「今日已打卡」恢复时，保留当日打卡记录，只是回到进行中可继续查看/编辑
    if (status == 0 && oldStatus == 2) {
      _clearTodayProgress(habitId);
    }

    habit.status = status;
    _saveHabits();
    if (status == 0) {
      _scheduleNotificationForHabit(habit);
    } else {
      NotificationService().cancelNotification(habit.id % 2147483647);
    }
    notifyListeners();
  }

  /// 从暂停恢复时清除当日所有打卡记录，恢复到初始空白状态
  void _clearTodayProgress(int habitId) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex < 0) return;

    // 删除当日所有打卡记录（完全清除，恢复到初始状态）
    _records.removeWhere((r) => r.habitId == habitId && r.date == todayDate);

    // 重新计算累计天数（只统计已完成的记录）
    _habits[habitIndex].totalDays =
        _records.where((r) => r.habitId == habitId && r.isCompleted).length;

    _saveHabits();
    _saveRecords();
  }

  // Schedule notification helper
  void _scheduleNotificationForHabit(HabitPlan habit) {
    if (habit.remindTime != null) {
      // Use habit ID to ensure uniqueness and allow cancellation/updates
      // Using modulo to keep ID within typical 32-bit integer limits for notifications
      final notificationId = habit.id % 2147483647; 
      
      NotificationService().scheduleDailyNotification(
        id: notificationId,
        title: '习惯打卡提醒',
        body: '该去完成你的习惯【${habit.title}】啦！',
        hour: habit.remindTime!.hour,
        minute: habit.remindTime!.minute,
        second: habit.remindTime!.second,
      );
    } else {
      // If remindTime is removed, cancel existing notification
      NotificationService().cancelNotification(habit.id % 2147483647);
    }
  }

  // Toggle record completion for a specific date
  void toggleHabitCompletion(int habitId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex < 0) return;
    final habit = _habits[habitIndex];
    // 「进行中」和「今日已打卡」都可以打卡/取消打卡；「已暂停」不能打卡
    if (habit.status == 2) return;

    final existingIndex = _records.indexWhere(
        (r) => r.habitId == habitId && r.date == normalizedDate);

    if (habit.multiTarget) {
      final int target = habit.dailyTarget <= 0 ? 1 : habit.dailyTarget;
      final int step = habit.perComplete <= 0 ? 1 : habit.perComplete;

      if (existingIndex >= 0) {
        final record = _records[existingIndex];
        if (record.isCompleted) {
          // 多目标模式下：不要直接把记录清空到 0，
          // 否则用户会感知成“又变成一天一次”。
          final nextValue = record.value - step;
          if (nextValue <= 0) {
            _records.removeAt(existingIndex);
          } else {
            record.value = nextValue;
            record.isCompleted = record.value >= target;
          }
        } else {
          final nextValue = record.value + step;
          record.value = nextValue >= target ? target : nextValue;
          record.isCompleted = record.value >= target;
        }
      } else {
        final int value = step >= target ? target : step;
        final record = CheckInLog(
          id: DateTime.now().millisecondsSinceEpoch,
          habitId: habitId,
          date: normalizedDate,
          isCompleted: value >= target,
          value: value,
        );
        _records.add(record);
      }
    } else {
      if (existingIndex >= 0) {
        final record = _records[existingIndex];
        record.isCompleted = !record.isCompleted;
        if (!record.isCompleted) {
          _records.removeAt(existingIndex);
        }
      } else {
        final record = CheckInLog(
          id: DateTime.now().millisecondsSinceEpoch,
          habitId: habitId,
          date: normalizedDate,
          isCompleted: true,
          value: 1,
        );
        _records.add(record);
      }
    }
    
    // 累计打卡天数 = 有「完成记录」的不重复日期数（同一天多次打卡只算1天）
    _habits[habitIndex].totalDays = _records
        .where((r) => r.habitId == habitId && r.isCompleted)
        .map((r) => r.date)
        .toSet()
        .length;

    // 检测当日是否已完成，更新状态
    final todayRecord = _records.firstWhere(
      (r) => r.habitId == habitId && r.date == normalizedDate && r.isCompleted,
      orElse: () => CheckInLog(id: -1, habitId: -1, date: normalizedDate, isCompleted: false, value: 0),
    );
    if (todayRecord.id != -1) {
      // 当日已完成，标记为「今日已打卡」
      _habits[habitIndex].status = 1;
      _habits[habitIndex].completedDate = normalizedDate;
      // 当日不再提醒（取消通知），次日自动恢复时会重新设置
      NotificationService().cancelNotification(habit.id % 2147483647);
    } else {
      // 当日未完成（取消打卡），恢复为「进行中」
      _habits[habitIndex].status = 0;
      _habits[habitIndex].completedDate = null;
      // 重新设置通知（如果有提醒时间）
      if (habit.remindTime != null) {
        NotificationService().scheduleDailyNotification(
          id: habit.id % 2147483647,
          title: '习惯打卡提醒',
          body: '该完成习惯「${habit.title}」了',
          hour: habit.remindTime!.hour,
          minute: habit.remindTime!.minute,
          second: 0,
        );
      }
    }

    _saveHabits();
    _saveRecords();
    notifyListeners();
  }

  // Check if a habit is completed on a specific date
  bool isHabitCompletedOnDate(int habitId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _records.any((r) => r.habitId == habitId && r.date == normalizedDate && r.isCompleted);
  }

  // Calculate accumulated days for a habit
  int getAccumulatedDays(int habitId) {
    return _records.where((r) => r.habitId == habitId && r.isCompleted).length;
  }

  /// 判断某习惯在指定日期是否属于「应打卡日」
  /// fixed = 每天；weekly = 查 weekday(1=周一,7=周日)；monthly = 查 day-of-month
  bool isScheduledForDate(HabitPlan habit, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // 未到开始日期
    final startDay = DateTime(
        habit.startDate.year, habit.startDate.month, habit.startDate.day);
    if (normalizedDate.isBefore(startDay)) return false;

    // 已超过结束日期
    if (habit.endDate != null) {
      final endDay = DateTime(
          habit.endDate!.year, habit.endDate!.month, habit.endDate!.day);
      if (normalizedDate.isAfter(endDay)) return false;
    }

    switch (habit.repeatType) {
      case 'weekly':
        return habit.repeatDays.contains(date.weekday);
      case 'monthly':
        return habit.repeatDays.contains(date.day);
      case 'fixed':
      default:
        return true;
    }
  }

  /// 规划页「我的一天」：展示今日日程内的所有习惯（含已暂停，方便右滑恢复）
  List<HabitPlan> getHabitsForDate(DateTime date) {
    return _habits.where((h) => isScheduledForDate(h, date)).toList();
  }

  // Get completed habits count for a specific date
  int getCompletedCountForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _records.where((r) => r.date == normalizedDate && r.isCompleted).length;
  }

  // Get total in-progress habits
  int get inProgressCount => _habits.where((h) => h.status == 0).length;
  int get completedCount => _habits.where((h) => h.status == 1).length;
  int get pausedCount => _habits.where((h) => h.status == 2).length;

  // Add Event
  void addEvent(EventItem event) {
    _events.add(event);
    _saveEvents();
    notifyListeners();
  }

  void deleteEvent(int eventId) {
    _events.removeWhere((e) => e.id == eventId);
    _saveEvents();
    notifyListeners();
  }

  // Seed data
  List<HabitPlan> _generateInitialMockHabits() {
    return [
      HabitPlan(
        id: 1,
        title: '扇贝英语一万句',
        iconKey: 'book',
        colorValue: 0xFF5599FF,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '上午',
        startDate: DateTime.now(),
        unit: '次',
        dailyTarget: 1,
        perComplete: 1,
        totalDays: 4,
      ),
      HabitPlan(
        id: 2,
        title: '家务',
        iconKey: 'cleaning_services',
        colorValue: 0xFFFF9933,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '全天',
        startDate: DateTime.now(),
        unit: '次',
        dailyTarget: 1,
        perComplete: 1,
        totalDays: 2,
      ),
      HabitPlan(
        id: 3,
        title: '早起',
        iconKey: 'wb_sunny',
        colorValue: 0xFF44CC88,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '上午',
        startDate: DateTime.now(),
        unit: '次',
        dailyTarget: 1,
        perComplete: 1,
        totalDays: 7,
      ),
      HabitPlan(
        id: 4,
        title: '诵经',
        iconKey: 'menu_book',
        colorValue: 0xFF9966CC,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '上午',
        startDate: DateTime.now(),
        unit: '次',
        dailyTarget: 1,
        perComplete: 1,
        totalDays: 1,
      ),
      HabitPlan(
        id: 5,
        title: '运动',
        iconKey: 'directions_run',
        colorValue: 0xFFFF5555,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '下午',
        startDate: DateTime.now(),
        unit: '分钟',
        dailyTarget: 30,
        perComplete: 30,
        totalDays: 5,
      ),
      HabitPlan(
        id: 6,
        title: '茶熏',
        iconKey: 'local_cafe',
        colorValue: 0xFFAA8855,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '晚上',
        startDate: DateTime.now(),
        unit: '次',
        dailyTarget: 1,
        perComplete: 1,
        totalDays: 3,
      ),
      HabitPlan(
        id: 7,
        title: '看书',
        iconKey: 'library_books',
        colorValue: 0xFF5599FF,
        repeatType: 'fixed',
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: '全天',
        startDate: DateTime.now(),
        unit: '页',
        dailyTarget: 10,
        perComplete: 10,
        totalDays: 0,
      ),
    ];
  }
}
