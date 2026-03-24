import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:intl/intl.dart';

class PlanView extends StatefulWidget {
  final VoidCallback? onAddTap;

  const PlanView({super.key, this.onAddTap});

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  final DateTime _today = DateTime.now();
  int _currentTab = 0; // 0: 我的一天, 1: 周, 2: 我的一月

  void _toggleComplete(int id) {
    context.read<HabitProvider>().toggleHabitCompletion(id, _today);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final List<HabitPlan> items = provider.getHabitsForDate(_today);
    
    // Sort items by timeOfDay for simple mock
    items.sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));

    String formattedDate = DateFormat('MM / dd EEEE', 'zh_CN').format(_today);
    // basic zh_CN fallback if intl locale not fully loaded
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    formattedDate = '${DateFormat('MM / dd').format(_today)} ${weekdays[_today.weekday - 1]}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _currentTab = 0),
              child: Text(
                '我的一天',
                style: TextStyle(
                  color: _currentTab == 0 ? Colors.black87 : Colors.grey[400],
                  fontSize: _currentTab == 0 ? 20 : 16,
                  fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _currentTab = 1),
              child: Text(
                '周',
                style: TextStyle(
                  color: _currentTab == 1 ? Colors.black87 : Colors.grey[400],
                  fontSize: _currentTab == 1 ? 20 : 16,
                  fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _currentTab = 2),
              child: Text(
                '我的一月',
                style: TextStyle(
                  color: _currentTab == 2 ? Colors.black87 : Colors.grey[400],
                  fontSize: _currentTab == 2 ? 20 : 16,
                  fontWeight: _currentTab == 2 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentTab == 0 ? formattedDate : (_currentTab == 1 ? '本周' : '${_today.year}年${_today.month}月'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.more_horiz, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_currentTab == 0)
            _buildDayView(items, provider)
          else if (_currentTab == 1)
            const Center(child: Text('周视图待开发', style: TextStyle(color: Colors.grey)))
          else
            _buildMonthView(provider),
          
          // Floating Action Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'plan_add',
              backgroundColor: const Color(0xFF5599FF),
              elevation: 4,
              onPressed: widget.onAddTap,
              child: const Icon(Icons.add, size: 32, color: Colors.white),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(List<HabitPlan> items, HabitProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Stack(
        children: [
          // Timeline line
          if (items.isNotEmpty)
            Positioned(
              left: 64,
              top: 0,
              bottom: 0,
              width: 1,
              child: Container(color: Colors.grey[300]),
            ),
          
          // List of items
          if (items.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('今天所有的任务都完成了，真棒！', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          else
            ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.only(bottom: 80), // Space for FAB
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildTimelineItem(item, provider);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthView(HabitProvider provider) {
    // A complex TableCalendar representing screenshot 8
    final firstDayOfMonth = DateTime(_today.year, _today.month, 1);
    final daysInMonth = DateTime(_today.year, _today.month + 1, 0).day;
    int startingWeekday = firstDayOfMonth.weekday;

    return Column(
      children: [
        // Weekdays Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[800], fontSize: 14),
                      ),
                    ))
                .toList(),
          ),
        ),
        
        // Calendar Grid
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Colors.grey[100]!, width: 1),
              children: _buildCalendarRows(provider, daysInMonth, startingWeekday),
            ),
          ),
        ),
      ],
    );
  }

  List<TableRow> _buildCalendarRows(HabitProvider provider, int daysInMonth, int startingWeekday) {
    List<TableRow> rows = [];
    int currentDay = 1;

    for (int week = 0; week < 6; week++) {
      if (currentDay > daysInMonth) break;

      List<Widget> rowChildren = [];
      for (int i = 1; i <= 7; i++) {
        if (week == 0 && i < startingWeekday) {
          rowChildren.add(Container(height: 120, color: Colors.grey[50]));
        } else if (currentDay > daysInMonth) {
          rowChildren.add(Container(height: 120, color: Colors.grey[50]));
        } else {
          final date = DateTime(_today.year, _today.month, currentDay);
          final isToday = date.day == _today.day;
          
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final records = provider.records.where((r) => r.date == normalizedDate && r.isCompleted).toList();
          
          List<Widget> tags = [];
          for (var record in records) {
            final habit = provider.habits.cast<HabitPlan?>().firstWhere((h) => h?.id == record.habitId, orElse: () => null);
            if (habit != null) {
              tags.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: Color(habit.colorValue),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 8, color: Colors.white),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          habit.title,
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              );
            }
          }

          int extraCount = tags.length > 5 ? tags.length - 5 : 0;

          rowChildren.add(
            Container(
              height: 120,
              decoration: BoxDecoration(color: isToday ? Colors.blue[50] : Colors.white),
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    currentDay.toString(), 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.blue : Colors.black87,
                    )
                  ),
                  const SizedBox(height: 4),
                  ...tags.take(5),
                  if (extraCount > 0)
                    Text('+$extraCount', style: TextStyle(fontSize: 8, color: Colors.grey[600]), textAlign: TextAlign.center),
                ],
              ),
            )
          );
          currentDay++;
        }
      }
      rows.add(TableRow(children: rowChildren));
    }

    return rows;
  }

  Widget _buildTimelineItem(HabitPlan item, HabitProvider provider) {
    final bool isCompleted = provider.isHabitCompletedOnDate(item.id, _today);
    final String timeDisplay = item.timeOfDay;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0, right: 12.0),
              child: Text(
                timeDisplay,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? Colors.grey[300] : Colors.grey[500],
                ),
              ),
            ),
          ),
          
          // Card column with timeline dot
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Card
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Check button
                        GestureDetector(
                          onTap: () => _toggleComplete(item.id),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted ? const Color(0xFF44CC88) : Colors.transparent,
                              border: Border.all(
                                color: isCompleted 
                                    ? const Color(0xFF44CC88)
                                    : Color(item.colorValue),
                                width: 1.5,
                              ),
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                        
                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? Colors.grey[400] : Colors.black87,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '习惯打卡: ${item.repeatType == 'fixed' ? '每天' : '重复'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCompleted ? Colors.grey[300] : Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCompleted ? '今日1/1次 100%' : '0/1次 0%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCompleted ? Colors.grey[300] : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Timeline dot
                Positioned(
                  left: -5,
                  top: 16,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? Colors.grey[300] : Colors.white,
                      border: isCompleted 
                          ? null 
                          : Border.all(color: const Color(0xFF5599FF), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
