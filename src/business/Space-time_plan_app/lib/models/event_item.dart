import 'package:flutter/material.dart';

// 用于"事项"和"规划"Tab
class EventItem {
  int id;
  String title;
  DateTime startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isAllDay;
  String repeatRule; // 重复规则
  bool skipHolidays;
  bool skipWeekends;
  int colorValue;

  EventItem({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.isAllDay,
    required this.repeatRule,
    required this.skipHolidays,
    required this.skipWeekends,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
        'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
        'isAllDay': isAllDay,
        'repeatRule': repeatRule,
        'skipHolidays': skipHolidays,
        'skipWeekends': skipWeekends,
        'colorValue': colorValue,
      };

  factory EventItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return EventItem(
      id: json['id'],
      title: json['title'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      startTime: parseTime(json['startTime']),
      endTime: parseTime(json['endTime']),
      isAllDay: json['isAllDay'],
      repeatRule: json['repeatRule'],
      skipHolidays: json['skipHolidays'],
      skipWeekends: json['skipWeekends'],
      colorValue: json['colorValue'],
    );
  }
}
