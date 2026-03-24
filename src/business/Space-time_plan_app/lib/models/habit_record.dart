// 用于记录每一天的打卡情况
class CheckInLog {
  int id;
  int habitId; // 关联的HabitPlan id
  DateTime date; // 打卡日期 (仅年月日)
  bool isCompleted; // 当天是否完成
  int value; // 完成的数值

  CheckInLog({
    required this.id,
    required this.habitId,
    required this.date,
    this.isCompleted = false,
    this.value = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'habitId': habitId,
        'date': date.toIso8601String(),
        'isCompleted': isCompleted,
        'value': value,
      };

  factory CheckInLog.fromJson(Map<String, dynamic> json) => CheckInLog(
        id: json['id'],
        habitId: json['habitId'],
        date: DateTime.parse(json['date']),
        isCompleted: json['isCompleted'],
        value: json['value'],
      );

  // Helper to easily strip time components from a DateTime
  static DateTime normalizeDate(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }
}
