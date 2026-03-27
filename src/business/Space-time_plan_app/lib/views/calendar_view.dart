import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/models/event_item.dart';
import 'package:space_time_plan_app/data/chinese_holidays.dart';
import 'package:space_time_plan_app/data/lunar_calendar.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  final DateTime _today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  static const _accent = Color(0xFF5599FF);

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
    _selectedDate = _today;
  }

  // ── 日历计算 ──────────────────────────────────────────────────
  int get _daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  // Dart weekday: Mon=1…Sun=7 → 周日作第一列 → %7: Mon=1,…Sat=6,Sun=0
  int get _startOffset {
    final w = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    return w % 7;
  }

  // ── 事项辅助 ──────────────────────────────────────────────────
  List<EventItem> _eventsForDate(List<EventItem> all, DateTime date) =>
      all.where((e) {
        final d =
            DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
        return d == date;
      }).toList();

  // ── 导航 ─────────────────────────────────────────────────────
  void _goToMonth(int delta) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
      final maxDay =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      _selectedDate = DateTime(
          _currentMonth.year,
          _currentMonth.month,
          _selectedDate.day.clamp(1, maxDay));
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(_today.year, _today.month, 1);
      _selectedDate = _today;
    });
  }

  /// 点击年份 → 滚轮选年
  void _pickYear() {
    final int minYear = 2020;
    final int maxYear = 2035;
    int tempYear = _currentMonth.year;
    final controller =
        FixedExtentScrollController(initialItem: tempYear - minYear);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('选择年份',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentMonth =
                              DateTime(tempYear, _currentMonth.month, 1);
                          final maxDay = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month + 1,
                                  0)
                              .day;
                          _selectedDate = DateTime(
                              _currentMonth.year,
                              _currentMonth.month,
                              _selectedDate.day.clamp(1, maxDay));
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('确定',
                          style: TextStyle(
                              color: _accent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 46,
                  perspective: 0.003,
                  diameterRatio: 2.0,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (i) => tempYear = minYear + i,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: maxYear - minYear + 1,
                    builder: (ctx, i) {
                      final y = minYear + i;
                      return Center(
                        child: Text(
                          '$y 年',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: y == tempYear
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: y == _currentMonth.year
                                ? _accent
                                : Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  /// 点击月份 → 12 宫格选月
  void _pickMonth() {
    int tempMonth = _currentMonth.month;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SizedBox(
            height: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_currentMonth.year} 年',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(
                                _currentMonth.year, tempMonth, 1);
                            final maxDay = DateTime(_currentMonth.year,
                                    _currentMonth.month + 1, 0)
                                .day;
                            _selectedDate = DateTime(
                                _currentMonth.year,
                                _currentMonth.month,
                                _selectedDate.day.clamp(1, maxDay));
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('确定',
                            style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, i) {
                      final m = i + 1;
                      final isSelected = m == tempMonth;
                      final isCurrent = m == _currentMonth.month;
                      return GestureDetector(
                        onTap: () => setSheet(() => tempMonth = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accent
                                : (isCurrent
                                    ? _accent.withValues(alpha: 0.08)
                                    : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(8),
                            border: isCurrent && !isSelected
                                ? Border.all(
                                    color: _accent.withValues(alpha: 0.4),
                                    width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$m月',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isCurrent
                                        ? _accent
                                        : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── 添加事项弹窗 ───────────────────────────────────────────────
  void _showAddEventSheet() {
    final titleCtrl = TextEditingController();
    bool isAllDay = false;
    DateTime startDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    int colorValue = 0xFF5599FF;
    final colorOptions = [
      0xFF5599FF, 0xFF44CC88, 0xFFFF9933,
      0xFFFF5555, 0xFF9966CC, 0xFFAA8855,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消',
                            style: TextStyle(color: Colors.black54)),
                      ),
                      const Text('添加事项',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请输入事项名称')),
                            );
                            return;
                          }
                          final event = EventItem(
                            id: DateTime.now().millisecondsSinceEpoch,
                            title: title,
                            startDate: startDate,
                            isAllDay: isAllDay,
                            startTime: isAllDay ? null : startTime,
                            endTime: isAllDay ? null : endTime,
                            repeatRule: 'none',
                            skipHolidays: false,
                            skipWeekends: false,
                            colorValue: colorValue,
                          );
                          context.read<HabitProvider>().addEvent(event);
                          Navigator.pop(ctx);
                        },
                        child: const Text('保存',
                            style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: '事项名称',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: colorOptions
                        .map((c) => GestureDetector(
                              onTap: () => setSheet(() => colorValue = c),
                              child: Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: colorValue == c
                                      ? Border.all(
                                          color: Colors.black26, width: 2.5)
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('全天', style: TextStyle(fontSize: 16)),
                      Switch(
                        value: isAllDay,
                        onChanged: (v) => setSheet(() => isAllDay = v),
                        activeThumbColor: _accent,
                        activeTrackColor: _accent.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  if (!isAllDay) ...[
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开始时间'),
                      trailing: Text(startTime.format(ctx),
                          style: const TextStyle(color: _accent)),
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: ctx, initialTime: startTime);
                        if (picked != null) setSheet(() => startTime = picked);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('结束时间'),
                      trailing: Text(endTime.format(ctx),
                          style: const TextStyle(color: _accent)),
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: ctx, initialTime: endTime);
                        if (picked != null) setSheet(() => endTime = picked);
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('日期'),
                    trailing: Text(
                      '${startDate.year}/${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: _accent),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setSheet(() => startDate = picked);
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── 构建 ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final events = provider.events;
    final selectedEvents = _eventsForDate(events, _selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部标题 ─────────────────────────────────────
            _buildHeader(),

            // ── 日历主体 ─────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildWeekdayRow(),
                  _buildCalendarGrid(events),
                ],
              ),
            ),

            // ── 选中日信息栏 ─────────────────────────────────
            _buildDateInfoBar(),

            // ── 事项列表 ─────────────────────────────────────
            Expanded(child: _buildEventList(selectedEvents)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_add',
        backgroundColor: _accent,
        elevation: 4,
        onPressed: _showAddEventSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  // ── 顶部标题行 ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // 点击年份 → 年份选择器
          GestureDetector(
            onTap: _pickYear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.transparent,
              ),
              child: Text(
                '${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const Text(
            '/',
            style: TextStyle(
                fontSize: 18, color: Colors.black38, fontWeight: FontWeight.bold),
          ),
          // 点击月份 → 月份选择器
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _accent.withValues(alpha: 0.06),
              ),
              child: Text(
                _currentMonth.month.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── 周标题行 ───────────────────────────────────────────────────
  Widget _buildWeekdayRow() {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: List.generate(7, (i) {
          final isWeekend = i == 0 || i == 6;
          return Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isWeekend ? Colors.red[300] : Colors.grey[500],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 日历格子 ───────────────────────────────────────────────────
  Widget _buildCalendarGrid(List<EventItem> events) {
    final startOffset = _startOffset;
    final daysInMonth = _daysInMonth;
    final total = ((startOffset + daysInMonth) / 7.0).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.65,
        mainAxisSpacing: 2,
      ),
      itemCount: total,
      itemBuilder: (ctx, idx) {
        if (idx < startOffset || idx >= startOffset + daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = idx - startOffset + 1;
        final date =
            DateTime(_currentMonth.year, _currentMonth.month, day);
        return _buildDayCell(date, _eventsForDate(events, date));
      },
    );
  }

  // ── 单个日期格子 ───────────────────────────────────────────────
  Widget _buildDayCell(DateTime date, List<EventItem> dayEvents) {
    final isToday = date == _today;
    final isSelected = date == _selectedDate;

    final holiday = ChinaHolidayData.of(date);
    final isMakeup = holiday?.isWork ?? false;
    final isHoliday = holiday?.isOff ?? false;
    final isWeekend = !isMakeup &&
        (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);

    // 副标签（节日 / 节气 / 农历）
    final subLabel = LunarCalendar.getSubLabel(date);
    final isTerm = LunarCalendar.isSolarTerm(date);
    Color subColor = Colors.grey[400]!;
    if (isTerm) subColor = Colors.green[600]!;

    // 有事项圆点（非节日/节气时显示）
    Widget? dotWidget;
    if (dayEvents.isNotEmpty && !isTerm && holiday == null) {
      dotWidget = Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white70 : Color(dayEvents.first.colorValue),
          shape: BoxShape.circle,
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: isSelected
          ? _buildSelectedCell(date, holiday, subLabel, subColor, dotWidget)
          : _buildNormalCell(date, holiday, isToday, isHoliday, isWeekend,
              subLabel, subColor, dotWidget),
    );
  }

  /// 选中状态：圆角方框放大 + 底部短横线
  Widget _buildSelectedCell(DateTime date, ChinaHoliday? holiday,
      String subLabel, Color subColor, Widget? dot) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // 休 / 班 badge + 数字
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (holiday != null)
                    Positioned(
                      top: -2,
                      right: -8,
                      child: Text(
                        holiday.isOff ? '休' : '班',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: holiday.isOff
                              ? Colors.white70
                              : Colors.orange[200],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              // 副标签
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subLabel,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white70, height: 1.0),
                  ),
                  if (dot != null) ...[const SizedBox(width: 1), dot],
                ],
              ),
            ],
          ),
        ),
        // 底部短横线指示器
        const SizedBox(height: 3),
        Container(
          width: 16,
          height: 2.5,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  /// 普通状态：圆形背景 + 副标签
  Widget _buildNormalCell(
      DateTime date,
      ChinaHoliday? holiday,
      bool isToday,
      bool isHoliday,
      bool isWeekend,
      String subLabel,
      Color subColor,
      Widget? dot) {
    Color numColor;
    if (isToday) {
      numColor = _accent;
    } else if (isHoliday || isWeekend) {
      numColor = const Color(0xFFE53935);
    } else {
      numColor = const Color(0xFF1A1A1A);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isToday ? _accent.withValues(alpha: 0.1) : null,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: _accent, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    color: numColor,
                  ),
                ),
              ),
            ),
            if (holiday != null)
              Positioned(
                top: -1,
                right: -2,
                child: holiday.isOff
                    ? Text(
                        '休',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE53935),
                        ),
                      )
                    : Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFF9800), width: 1),
                        ),
                        child: const Center(
                          child: Text(
                            '班',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subLabel,
                style: TextStyle(fontSize: 9, color: subColor, height: 1.0)),
            if (dot != null) ...[const SizedBox(width: 1), dot],
          ],
        ),
      ],
    );
  }

  // ── 底部日期信息栏 ─────────────────────────────────────────────
  Widget _buildDateInfoBar() {
    final diff = _selectedDate.difference(_today).inDays;
    String diffLabel;
    if (diff == 0) {
      diffLabel = '今天';
    } else if (diff > 0) {
      diffLabel = '$diff天后';
    } else {
      diffLabel = '${-diff}天前';
    }

    final lunarLabel = LunarCalendar.getFullLabel(_selectedDate);
    final weekdayLabel =
        ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][_selectedDate.weekday % 7];

    return GestureDetector(
      onTap: () {
        // 将来可以展开详情
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 选中日数字
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedDate.month}月${_selectedDate.day}日 $weekdayLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$diffLabel  $lunarLabel',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const Spacer(),
            // 今 按钮
            GestureDetector(
              onTap: _goToToday,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _today == _selectedDate
                      ? _accent
                      : _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '今',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _today == _selectedDate ? Colors.white : _accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  // ── 事项列表 ───────────────────────────────────────────────────
  Widget _buildEventList(List<EventItem> selectedEvents) {
    if (selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('当天没有事项',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 4),
            Text('点击右下角 + 添加',
                style: TextStyle(color: Colors.grey[350], fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: selectedEvents.length,
      itemBuilder: (ctx, i) {
        final ev = selectedEvents[i];
        final timeStr = ev.isAllDay
            ? '全天'
            : (ev.startTime != null
                ? '${ev.startTime!.hour.toString().padLeft(2, '0')}:'
                    '${ev.startTime!.minute.toString().padLeft(2, '0')}'
                    '${ev.endTime != null ? ' - ${ev.endTime!.hour.toString().padLeft(2, '0')}:${ev.endTime!.minute.toString().padLeft(2, '0')}' : ''}'
                : '');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: Color(ev.colorValue), width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Color(ev.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              ev.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: timeStr.isNotEmpty
                ? Text(timeStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              onPressed: () =>
                  context.read<HabitProvider>().deleteEvent(ev.id),
            ),
          ),
        );
      },
    );
  }
}
