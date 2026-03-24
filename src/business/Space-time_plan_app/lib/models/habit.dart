import 'package:flutter/material.dart';

// 用于存储“习惯打卡”Tab下的计划
class HabitPlan {
  int id;
  String title; // 标题，如"扇贝英语一万句"
  String iconKey; // 图标标识或Unicode
  int colorValue; // 图标的背景色int值
  String repeatType; // "fixed"(每天) / "weekly" / "monthly"
  List<int> repeatDays; // [1,2,3,4,5,6,7] 1=周一
  String timeOfDay; // "全天"/"上午"/"下午"/"晚上"
  DateTime? remindTime; // 提醒的具体时间
  DateTime startDate;
  DateTime? endDate; // 为null表示"长期"
  String unit; // 单位，如"次"、"分钟"
  int dailyTarget; // 每日目标，如1
  int perComplete; // 单次完成量，如1
  int status; // 0:进行中, 1:已完成, 2:已暂停
  int totalDays; // 累计打卡天数

  HabitPlan({
    required this.id,
    required this.title,
    required this.iconKey,
    required this.colorValue,
    required this.repeatType,
    required this.repeatDays,
    required this.timeOfDay,
    this.remindTime,
    required this.startDate,
    this.endDate,
    required this.unit,
    required this.dailyTarget,
    required this.perComplete,
    this.status = 0,
    this.totalDays = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'repeatType': repeatType,
        'repeatDays': repeatDays,
        'timeOfDay': timeOfDay,
        'remindTime': remindTime?.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'unit': unit,
        'dailyTarget': dailyTarget,
        'perComplete': perComplete,
        'status': status,
        'totalDays': totalDays,
      };

  factory HabitPlan.fromJson(Map<String, dynamic> json) => HabitPlan(
        id: json['id'],
        title: json['title'],
        iconKey: json['iconKey'],
        colorValue: json['colorValue'],
        repeatType: json['repeatType'],
        repeatDays: List<int>.from(json['repeatDays']),
        timeOfDay: json['timeOfDay'],
        remindTime: json['remindTime'] != null ? DateTime.parse(json['remindTime']) : null,
        startDate: DateTime.parse(json['startDate']),
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
        unit: json['unit'],
        dailyTarget: json['dailyTarget'],
        perComplete: json['perComplete'],
        status: json['status'],
        totalDays: json['totalDays'],
      );
}
