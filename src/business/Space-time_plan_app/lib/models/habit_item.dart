import 'package:flutter/material.dart';

class HabitItem {
  final String id;
  final String time;
  final String title;
  final String timeRange;
  bool isCompleted;
  final bool isHabit;
  final String color;
  final String frequency;
  final int accumulatedDays;
  final IconData icon;

  HabitItem({
    required this.id,
    required this.time,
    required this.title,
    required this.timeRange,
    this.isCompleted = false,
    this.isHabit = false,
    this.color = 'blue',
    this.frequency = '每天',
    this.accumulatedDays = 0,
    this.icon = Icons.star,
  });
}

// Global mock data to share between views for prototyping
final List<HabitItem> mockPlanItems = [
  HabitItem(
    id: '1',
    time: '05:00',
    title: '扇贝英语一万句',
    timeRange: '05:00~05:20',
    isCompleted: true,
    isHabit: true,
    color: 'orange',
    frequency: '每天',
    accumulatedDays: 4,
    icon: Icons.face,
  ),
  HabitItem(
    id: '2',
    time: '05:30',
    title: '家务',
    timeRange: '05:30~05:45',
    isCompleted: false,
    isHabit: true,
    color: 'green',
    frequency: '每周2天',
    accumulatedDays: 3,
    icon: Icons.cleaning_services,
  ),
  HabitItem(
    id: '3',
    time: '06:00',
    title: '早起',
    timeRange: '06:00~06:40',
    isCompleted: true,
    isHabit: true,
    color: 'orange',
    frequency: '每天',
    accumulatedDays: 8,
    icon: Icons.wb_sunny,
  ),
  HabitItem(
    id: '4',
    time: '06:30',
    title: '诵经',
    timeRange: '06:30~07:00',
    isCompleted: false,
    isHabit: true,
    color: 'red',
    frequency: '每天',
    accumulatedDays: 8,
    icon: Icons.favorite,
  ),
  HabitItem(
    id: '5',
    time: '07:00',
    title: '运动',
    timeRange: '07:00~07:40',
    isCompleted: false,
    isHabit: true,
    color: 'orange',
    frequency: '每天',
    accumulatedDays: 8,
    icon: Icons.fitness_center,
  ),
  HabitItem(
    id: '6',
    time: '07:30',
    title: '茶熏',
    timeRange: '07:30~08:00',
    isCompleted: false,
    isHabit: true,
    color: 'brown',
    frequency: '每天',
    accumulatedDays: 10,
    icon: Icons.self_improvement,
  ),
  HabitItem(
    id: '7',
    time: '08:00',
    title: '看书',
    timeRange: '08:00~08:30',
    isCompleted: false,
    isHabit: true,
    color: 'green',
    frequency: '每天',
    accumulatedDays: 4,
    icon: Icons.menu_book,
  ),
];
