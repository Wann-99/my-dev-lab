import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/widgets/edit_habit_bottom_sheet.dart';
import 'package:intl/intl.dart';

class PlanView extends StatefulWidget {
  final VoidCallback? onAddTap;

  const PlanView({super.key, this.onAddTap});

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  final DateTime _today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _currentTab = 0; // 0: 我的一天, 1: 周, 2: 我的一月

  // ── 周视图状态 ───────────────────────────────────────────────
  int _weekOffset = 0; // 0=本周, -1=上周, +1=下周 …
  late DateTime _weekSelectedDay;

  // 当前周视图的周一
  DateTime get _weekMonday {
    final base = _today.subtract(Duration(days: _today.weekday - 1));
    return base.add(Duration(days: 7 * _weekOffset));
  }

  // 当前周视图的 7 天
  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekMonday.add(Duration(days: i)));
  
  @override
  void initState() {
    super.initState();
    _weekSelectedDay = _today;
  }

  void _showCheckInNoteBottomSheet(HabitPlan habit, [DateTime? date]) {
    final targetDate = date ?? _today;
    final provider = context.read<HabitProvider>();
    final record = provider.getHabitRecordForDate(habit.id, targetDate);
    final controller = TextEditingController(text: record?.note ?? habit.checkInNote ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('跳过', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                  const Text('打卡心得', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  GestureDetector(
                    onTap: () {
                      final text = controller.text.trim();
                      provider.updateCheckInNote(habit.id, _today, text.isEmpty ? null : text);
                      Navigator.pop(context);
                    },
                    child: const Text('保存', style: TextStyle(color: Color(0xFF5599FF), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '写下打卡心得（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleComplete(int id, [DateTime? date]) {
    context.read<HabitProvider>().toggleHabitCompletion(id, date ?? _today);
  }

  Widget _buildTabButton(String label, int index) {
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? const Color(0xFF5599FF) : Colors.black45,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    // 规划页只显示今日应打卡的习惯（根据 repeatType/repeatDays/startDate/endDate 过滤）
    final List<HabitPlan> items = provider.getHabitsForDate(_today);

    // Sort: 进行中(0) 在前，今日已打卡(1) 在后，再按时间排序
    items.sort((a, b) {
      if (a.status != b.status) return a.status.compareTo(b.status);
      return a.timeOfDay.compareTo(b.timeOfDay);
    });

    String formattedDate = DateFormat('MM / dd EEEE', 'zh_CN').format(_today);
    // basic zh_CN fallback if intl locale not fully loaded
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    formattedDate = '${DateFormat('MM / dd').format(_today)} ${weekdays[_today.weekday - 1]}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // 日期信息
            Expanded(
              child: Text(
                _currentTab == 0
                    ? formattedDate
                    : (_currentTab == 1
                        ? '${_weekMonday.month}/${_weekMonday.day} — ${_weekMonday.add(const Duration(days: 6)).month}/${_weekMonday.add(const Duration(days: 6)).day}'
                        : '${_today.year}年${_today.month}月'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            // 分段选择器
            Container(
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabButton('一天', 0),
                  _buildTabButton('周', 1),
                  _buildTabButton('月', 2),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_currentTab == 0)
            _buildDayView(items, provider)
          else if (_currentTab == 1)
            _buildWeekView(provider)
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

  // ── 周视图 ────────────────────────────────────────────────────
  Widget _buildWeekView(HabitProvider provider) {
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final days = _weekDays;

    // 当前选中日的习惯列表
    final dayItems = provider.getHabitsForDate(_weekSelectedDay);
    dayItems.sort((a, b) {
      if (a.status != b.status) return a.status.compareTo(b.status);
      return a.timeOfDay.compareTo(b.timeOfDay);
    });

    // 统计每天的完成/总数
    Map<DateTime, (int done, int total)> dayStat = {};
    for (final d in days) {
      final scheduled = provider.getHabitsForDate(d);
      final done = scheduled.where((h) => provider.isHabitCompletedOnDate(h.id, d)).length;
      dayStat[d] = (done, scheduled.length);
    }

    return Column(
      children: [
        // ── 周导航 + 7 天日期条 ─────────────────────────────
        Container(
          color: Colors.white,
          child: Column(
            children: [
              // 上下周切换
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      color: Colors.black45,
                      onPressed: () => setState(() {
                        _weekOffset--;
                        // 选中新周内最近的一天（偏移周内同一个 weekday）
                        _weekSelectedDay = _weekSelectedDay
                            .subtract(const Duration(days: 7));
                      }),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _weekOffset = 0;
                        _weekSelectedDay = _today;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: _weekOffset == 0
                              ? const Color(0xFF5599FF).withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _weekOffset == 0 ? '本周' : '回本周',
                          style: TextStyle(
                            fontSize: 13,
                            color: _weekOffset == 0
                                ? const Color(0xFF5599FF)
                                : Colors.black54,
                            fontWeight: _weekOffset == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      color: Colors.black45,
                      onPressed: () => setState(() {
                        _weekOffset++;
                        _weekSelectedDay = _weekSelectedDay
                            .add(const Duration(days: 7));
                      }),
                    ),
                  ],
                ),
              ),
              // 7 天日期格子
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = days[i];
                    final isToday = day == _today;
                    final isSelected = day == _weekSelectedDay;
                    final stat = dayStat[day] ?? (0, 0);
                    final hasDone = stat.$1 > 0;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _weekSelectedDay = day),
                        child: Column(
                          children: [
                            Text(
                              weekLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: (i >= 5) // 周六日
                                    ? Colors.red[300]
                                    : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF5599FF)
                                    : (isToday
                                        ? const Color(0xFF5599FF)
                                            .withValues(alpha: 0.1)
                                        : Colors.transparent),
                                shape: BoxShape.circle,
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: const Color(0xFF5599FF),
                                        width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: (isToday || isSelected)
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : (isToday
                                            ? const Color(0xFF5599FF)
                                            : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 当天完成进度小圆点
                            if (stat.$2 > 0)
                              _buildWeekDayStat(stat.$1, stat.$2, isSelected)
                            else
                              const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        // ── 选中日期标签 ─────────────────────────────────────
        Container(
          color: const Color(0xFFF0F2F5),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                _weekSelectedDay == _today
                    ? '今天'
                    : '${_weekSelectedDay.month}月${_weekSelectedDay.day}日',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              if (dayItems.isNotEmpty)
                Text(
                  '${dayItems.where((h) => provider.isHabitCompletedOnDate(h.id, _weekSelectedDay)).length}/${dayItems.length} 完成',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
        ),

        // ── 当日习惯列表 ─────────────────────────────────────
        Expanded(
          child: dayItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('当天没有安排打卡的习惯',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 64,
                        top: 0,
                        bottom: 0,
                        width: 1,
                        child: Container(color: Colors.grey[200]),
                      ),
                      ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: dayItems.length,
                        itemBuilder: (ctx, i) => _buildTimelineItem(
                            dayItems[i], provider,
                            date: _weekSelectedDay),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// 周视图每天的完成情况小图标
  Widget _buildWeekDayStat(int done, int total, bool isSelected) {
    if (done == total) {
      // 全部完成：绿色实心点
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF44CC88),
          shape: BoxShape.circle,
        ),
      );
    }
    // 部分完成：横向进度条
    return SizedBox(
      width: 24,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: done / total,
          backgroundColor:
              isSelected ? Colors.white30 : Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF5599FF)),
        ),
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
                  Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('今天没有安排打卡的习惯', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('可在「习惯打卡」页查看和管理所有习惯', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
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

  void _showEditHabitBottomSheet(HabitPlan item, HabitProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EditHabitBottomSheet(habit: item);
      }
    );
  }

  Widget _buildTimelineItem(HabitPlan item, HabitProvider provider,
      {DateTime? date}) {
    final targetDate = date ?? _today;
    final bool isCompleted =
        provider.isHabitCompletedOnDate(item.id, targetDate);
    final String timeDisplay = item.timeOfDay;
    // 0:进行中, 1:今日已打卡, 2:已暂停
    final bool isPaused = item.status == 2;

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
                  child: Slidable(
                    key: ValueKey('plan_habit_${item.id}'),
                    // 右滑：进行中/今日已打卡 → 暂停；已暂停 → 恢复
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.25,
                      children: [
                        if (item.status != 2)
                          SlidableAction(
                            onPressed: (ctx) {
                              provider.setHabitStatus(item.id, 2);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('「${item.title}」已暂停'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            backgroundColor: const Color(0xFFFF9933),
                            foregroundColor: Colors.white,
                            icon: Icons.pause_circle_outline,
                            label: '暂停',
                            borderRadius: BorderRadius.circular(16),
                          )
                        else
                          SlidableAction(
                            onPressed: (ctx) {
                              provider.setHabitStatus(item.id, 0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('「${item.title}」已恢复进行中'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            backgroundColor: const Color(0xFF44CC88),
                            foregroundColor: Colors.white,
                            icon: Icons.play_circle_outline,
                            label: '恢复',
                            borderRadius: BorderRadius.circular(16),
                          ),
                      ],
                    ),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.4,
                      children: [
                        const SizedBox(width: 8), // Spacing from card
                        SlidableAction(
                          onPressed: (context) {
                            _showEditHabitBottomSheet(item, provider);
                          },
                          backgroundColor: const Color(0xFF5599FF),
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: '编辑',
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                        ),
                        SlidableAction(
                          onPressed: (context) {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  title: const Text("确认删除"),
                                  content: Text("确定要删除习惯“${item.title}”吗？\n删除后相关的打卡记录也会被清除。"),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                      child: const Text("取消", style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        provider.deleteHabit(item.id);
                                        Navigator.of(dialogContext).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('已删除: ${item.title}'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Text("删除", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: '删除',
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                        ),
                      ],
                    ),
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
                            onTap: isPaused
                                ? () {
                                    // 已暂停时点击提示
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('「${item.title}」已暂停，右滑可恢复'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : () {
                                    final wasCompletedBefore = provider
                                        .isHabitCompletedOnDate(item.id, targetDate);
                                    _toggleComplete(item.id, targetDate);
                                    final isCompletedNow = provider
                                        .isHabitCompletedOnDate(item.id, targetDate);
                                    if (item.autoPopup &&
                                        isCompletedNow &&
                                        !wasCompletedBefore) {
                                      Future.microtask(() =>
                                          _showCheckInNoteBottomSheet(
                                              item, targetDate));
                                    }
                                  },
                            child: Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPaused
                                    ? Colors.grey[300]
                                    : (isCompleted ? const Color(0xFF44CC88) : Colors.transparent),
                                border: Border.all(
                                  color: isPaused
                                      ? Colors.grey[400]!
                                      : (isCompleted
                                          ? const Color(0xFF44CC88)
                                          : Color(item.colorValue)),
                                  width: 1.5,
                                ),
                              ),
                              child: isCompleted && !isPaused
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : (isPaused ? Icon(Icons.pause, color: Colors.grey[500], size: 14) : null),
                            ),
                          ),
                          
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isPaused
                                              ? Colors.grey[500]
                                              : (isCompleted ? Colors.grey[400] : Colors.black87),
                                          decoration: isCompleted || isPaused ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (isPaused)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '已暂停',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    if (isCompleted && !isPaused)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF44CC88).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '今日已打卡',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: const Color(0xFF44CC88),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '习惯打卡: ${item.repeatType == 'fixed' ? '每天' : '重复'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPaused
                                            ? Colors.grey[400]
                                            : (isCompleted ? Colors.grey[300] : Colors.grey[500]),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Builder(
                                      builder: (context) {
                                        final record = provider.getHabitRecordForDate(item.id, targetDate);
                                        final int target = item.multiTarget ? item.dailyTarget : 1;
                                        final int safeTarget = target <= 0 ? 1 : target;
                                        final int value = record?.value ?? 0;
                                        final int safeValue = value > safeTarget ? safeTarget : value;
                                        final int percent = ((safeValue / safeTarget) * 100).round();
                                        final String unit = item.unit;
                                        return Text(
                                          '$safeValue/$safeTarget$unit $percent%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isPaused
                                                ? Colors.grey[400]
                                                : (isCompleted ? Colors.grey[300] : Colors.grey[400]),
                                          ),
                                        );
                                      },
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
                      color: isPaused
                          ? Colors.grey[300]
                          : (isCompleted ? Colors.grey[300] : Colors.white),
                      border: isPaused || isCompleted
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
