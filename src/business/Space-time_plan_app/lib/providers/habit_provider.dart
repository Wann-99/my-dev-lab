import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/models/habit_record.dart';
import 'package:space_time_plan_app/models/event_item.dart';

class HabitProvider extends ChangeNotifier {
  List<HabitPlan> _habits = [];
  List<CheckInLog> _records = [];
  List<EventItem> _events = [];

  List<HabitPlan> get habits => _habits;
  List<CheckInLog> get records => _records;
  List<EventItem> get events => _events;

  // Initialize and load data
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Habits
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
      _habits = _generateInitialMockHabits(); // Seed with some defaults if empty
      _saveHabits();
    }

    // Load Records
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

    // Load Events
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
    notifyListeners();
  }

  // Delete habit and its records
  void deleteHabit(int habitId) {
    _habits.removeWhere((h) => h.id == habitId);
    _records.removeWhere((r) => r.habitId == habitId);
    _saveHabits();
    _saveRecords();
    notifyListeners();
  }

  // Toggle record completion for a specific date
  void toggleHabitCompletion(int habitId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingIndex = _records.indexWhere(
        (r) => r.habitId == habitId && r.date == normalizedDate);

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
    
    // Update totalDays for the habit
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex >= 0) {
      _habits[habitIndex].totalDays = _records.where((r) => r.habitId == habitId && r.isCompleted).length;
      _saveHabits();
    }
    
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

  // Get all habits that apply to a specific date
  List<HabitPlan> getHabitsForDate(DateTime date) {
    return _habits; 
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
