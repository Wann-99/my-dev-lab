import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/models/event_item.dart';
import 'package:space_time_plan_app/data/chinese_holidays.dart';
import 'package:space_time_plan_app/data/lunar_calendar.dart';
import 'package:space_time_plan_app/utils/modal_sheet_utils.dart';
import 'package:space_time_plan_app/widgets/glass_card.dart';

class CalendarView extends StatefulWidget {
  /// 外部通过 `notifier.value++` 触发"添加事项"弹窗
  final ValueNotifier<int>? addTrigger;
  const CalendarView({super.key, this.addTrigger});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView>
    with WidgetsBindingObserver {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  DateTime _today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  static const _accent = AppTheme.primary;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
    _selectedDate = _today;
    WidgetsBinding.instance.addObserver(this);
    widget.addTrigger?.addListener(_onAddTrigger);
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addTrigger != widget.addTrigger) {
      oldWidget.addTrigger?.removeListener(_onAddTrigger);
      widget.addTrigger?.addListener(_onAddTrigger);
    }
  }

  @override
  void dispose() {
    widget.addTrigger?.removeListener(_onAddTrigger);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAddTrigger() => _showAddEventSheet();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      if (now != _today) {
        setState(() {
          _today = now;
          // 若当前视图还停在旧月，自动跳到今天所在月
          _currentMonth = DateTime(now.year, now.month, 1);
          _selectedDate = now;
        });
      }
    }
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

    popOpenModalBottomSheets(context);
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
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

    popOpenModalBottomSheets(context);
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
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
                                    ? AppTheme.primaryLight
                                    : AppTheme.bgMain),
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
                                        : AppTheme.textPrimary),
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
  // ── 添加事项完整弹窗 ───────────────────────────────────────────
  void _showAddEventSheet() {
    // 持久化状态（跨 StatefulBuilder rebuild 保留）
    String mode = 'allDay'; // 'point' | 'range' | 'allDay'
    final titleCtrl = TextEditingController();
    int colorValue = 0xFF4CAF50;
    DateTime sheetMonth =
        DateTime(_selectedDate.year, _selectedDate.month, 1);
    DateTime startDate = _selectedDate;
    DateTime? endDate;
    bool selectingSecond = false; // 全天模式：false=选开始 true=选结束
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    bool skipHolidays = false;
    bool skipWeekends = false;
    String repeatRule = 'none';

    const colorOptions = [
      0xFF4CAF50, 0xFF4FC3F7, 0xFFFFB74D,
      0xFFEF5350, 0xFF9C27B0, 0xFF795548,
    ];

    final pageContext = context;
    popOpenModalBottomSheets(pageContext);
    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return ScaffoldMessenger(
          child: StatefulBuilder(builder: (sheetCtx, setSheet) {
          // ── 日历辅助 ─────────────────────────────────────
          final int moOffset =
              DateTime(sheetMonth.year, sheetMonth.month, 1).weekday - 1;
          final int daysInMo =
              DateTime(sheetMonth.year, sheetMonth.month + 1, 0).day;
          final int totalCells = ((moOffset + daysInMo) / 7.0).ceil() * 7;

          DateTime? normStart =
              DateTime(startDate.year, startDate.month, startDate.day);
          DateTime? normEnd = endDate == null
              ? null
              : DateTime(endDate!.year, endDate!.month, endDate!.day);

          bool isStart(DateTime d) =>
              DateTime(d.year, d.month, d.day) == normStart;
          bool isEnd(DateTime d) =>
              normEnd != null &&
              DateTime(d.year, d.month, d.day) == normEnd;
          bool inRange(DateTime d) {
            if (mode != 'allDay' || normEnd == null) return false;
            final n = DateTime(d.year, d.month, d.day);
            return n.isAfter(normStart) && n.isBefore(normEnd);
          }

          // ── 日期格子 ─────────────────────────────────────
          Widget buildDayCell(DateTime date) {
            final isT = date == _today;
            final isSel = isStart(date);
            final isE = isEnd(date);
            final inR = inRange(date);
            final holiday = ChinaHolidayData.of(date);
            final subLabel = LunarCalendar.getSubLabel(date);
            final isMakeup = holiday?.isWork ?? false;
            final isWeekend =
                !isMakeup && (date.weekday == 6 || date.weekday == 7);

            Color numColor;
            if (isSel || isE) {
              numColor = Colors.white;
            } else if (isT) {
              numColor = _accent;
            } else if (holiday?.isOff == true || isWeekend) {
              numColor = const Color(0xFFE53935);
            } else {
              numColor = AppTheme.textPrimary;
            }

            return GestureDetector(
              onTap: () => setSheet(() {
                if (mode == 'allDay') {
                  if (!selectingSecond) {
                    startDate = date;
                    endDate = null;
                    selectingSecond = true;
                  } else {
                    if (date.isAfter(startDate)) {
                      endDate = date;
                    } else if (date.isBefore(startDate)) {
                      endDate = startDate;
                      startDate = date;
                    }
                    selectingSecond = false;
                  }
                } else {
                  startDate = date;
                }
              }),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: inR
                      ? _accent.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (isSel || isE)
                                ? _accent
                                : (isT
                                    ? _accent.withValues(alpha: 0.1)
                                    : null),
                            shape: BoxShape.circle,
                            border: isT && !isSel && !isE
                                ? Border.all(color: _accent, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: (isSel || isE || isT)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: numColor,
                              ),
                            ),
                          ),
                        ),
                        if (holiday != null)
                          Positioned(
                            top: -1,
                            right: -2,
                            child: Text(
                              holiday.isOff ? '休' : '班',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isSel || isE
                                    ? Colors.white70
                                    : (holiday.isOff
                                        ? const Color(0xFFE53935)
                                        : Colors.orange),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.0,
                        color: isSel || isE
                            ? Colors.white70
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── 日历 Widget ─────────────────────────────────
          Widget buildCalendar() {
            const moLabels = ['一', '二', '三', '四', '五', '六', '日'];
            return Column(
              children: [
                // 月份导航
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () => setSheet(() {
                        sheetMonth = DateTime(
                            sheetMonth.year, sheetMonth.month - 1, 1);
                      }),
                    ),
                    Text(
                      '${sheetMonth.year}/${sheetMonth.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () => setSheet(() {
                        sheetMonth = DateTime(
                            sheetMonth.year, sheetMonth.month + 1, 1);
                      }),
                    ),
                  ],
                ),
                // 星期标题（周一到周日）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: moLabels
                        .map((l) => Expanded(
                              child: Center(
                                child: Text(l,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                // 日期格子
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (_, idx) {
                    final dayNum = idx - moOffset + 1;
                    if (dayNum < 1 || dayNum > daysInMo) {
                      return const SizedBox.shrink();
                    }
                    return buildDayCell(
                        DateTime(sheetMonth.year, sheetMonth.month, dayNum));
                  },
                ),
              ],
            );
          }

          // ── 提示文字 ────────────────────────────────────
          String hintText;
          if (mode == 'allDay') {
            hintText = normEnd != null
                ? '${startDate.month}/${startDate.day} — ${endDate!.month}/${endDate!.day}'
                : (selectingSecond ? '再选一个日期作为结束日期' : '选择2个日期可跨多天');
          } else {
            final d = normStart;
            hintText =
                '已选：${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
          }

          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppTheme.bgMain,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // ── 顶部操作栏 ────────────────────────────
                Container(
                  color: AppTheme.bgCard,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setSheet(() {
                                  startDate = _selectedDate;
                                  endDate = null;
                                  selectingSecond = false;
                                  repeatRule = 'none';
                                  skipHolidays = false;
                                  skipWeekends = false;
                                });
                              },
                              child: const Text('清除',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 15)),
                            ),
                            // 模式切换器
                            Expanded(
                              child: Center(
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _modeBtn('时间点', 'point', mode,
                                          (m) => setSheet(() {
                                                mode = m;
                                                endDate = null;
                                              })),
                                      _modeBtn('时间段', 'range', mode,
                                          (m) => setSheet(() {
                                                mode = m;
                                                endDate = null;
                                              })),
                                      _modeBtn('全天', 'allDay', mode,
                                          (m) => setSheet(() {
                                                mode = m;
                                              })),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    const SnackBar(
                                        content: Text('请输入事项名称')),
                                  );
                                  return;
                                }
                                final event = EventItem(
                                  id: DateTime.now().millisecondsSinceEpoch,
                                  title: title,
                                  startDate: startDate,
                                  endDate:
                                      mode == 'allDay' ? endDate : null,
                                  isAllDay: mode == 'allDay',
                                  startTime:
                                      mode != 'allDay' ? startTime : null,
                                  endTime:
                                      mode == 'range' ? endTime : null,
                                  repeatRule: repeatRule,
                                  skipHolidays: skipHolidays,
                                  skipWeekends: skipWeekends,
                                  colorValue: colorValue,
                                );
                                FocusScope.of(sheetCtx).unfocus();
                                // 必须在 pop 之前拿到动画引用
                                final routeAnim =
                                    ModalRoute.of(modalCtx)?.animation;
                                Navigator.pop(modalCtx);
                                // 等动画到达 dismissed 再 +1 帧调用 addEvent，
                                // 此时 route 元素已彻底从树中移除，notifyListeners 安全
                                if (routeAnim != null) {
                                  void onStatus(AnimationStatus s) {
                                    if (s == AnimationStatus.dismissed) {
                                      routeAnim.removeStatusListener(onStatus);
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          pageContext
                                              .read<HabitProvider>()
                                              .addEvent(event);
                                        }
                                      });
                                    }
                                  }
                                  routeAnim.addStatusListener(onStatus);
                                }
                              },
                              child: const Text('确定',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      // 事项名称输入
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            // 颜色选择球
                            GestureDetector(
                              onTap: () => _showColorPicker(
                                  sheetCtx, colorValue,
                                  colorOptions.toList(),
                                  (c) => setSheet(() => colorValue = c)),
                              child: Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Color(colorValue),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.circle,
                                    size: 10, color: Colors.white30),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: titleCtrl,
                                style: const TextStyle(fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: '添加事项名称',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 滚动内容区 ────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 日历
                        Container(
                          color: AppTheme.bgCard,
                          padding: const EdgeInsets.only(bottom: 4),
                          child: buildCalendar(),
                        ),

                        // 提示文字
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            hintText,
                            style: TextStyle(
                              fontSize: 13,
                              color: normEnd != null && mode == 'allDay'
                                  ? Colors.black54
                                  : _accent,
                            ),
                          ),
                        ),

                        // ── 时间/重复设置卡 ────────────────
                        Container(
                          color: AppTheme.bgCard,
                          margin: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              if (mode != 'allDay') ...[
                                // 时间段/时间点 设置
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child: Text('重复',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500]))),
                                      Expanded(
                                          flex: 4,
                                          child: Text('开始日期',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500]))),
                                      Expanded(
                                          flex: 4,
                                          child: Text(
                                              mode == 'point'
                                                  ? '时间点'
                                                  : '时间段',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500]))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 10, 16, 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: GestureDetector(
                                          onTap: () => _showRepeatSheet(
                                              sheetCtx,
                                              repeatRule,
                                              (v) => setSheet(
                                                  () => repeatRule = v)),
                                          child: Text(
                                            _repeatLabel(repeatRule),
                                            style: const TextStyle(
                                                color: _accent,
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          '${startDate.year}/${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final p =
                                                await showTimePicker(
                                                    context: sheetCtx,
                                                    initialTime: startTime);
                                            if (p != null) {
                                              setSheet(
                                                  () => startTime = p);
                                            }
                                          },
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mode == 'range'
                                                    ? '${_fmtTime(startTime)} — ${_fmtTime(endTime)}'
                                                    : _fmtTime(startTime),
                                                style: const TextStyle(
                                                    color: _accent,
                                                    fontSize: 13),
                                              ),
                                              if (mode == 'range')
                                                GestureDetector(
                                                  onTap: () async {
                                                    final p =
                                                        await showTimePicker(
                                                            context: sheetCtx,
                                                            initialTime:
                                                                endTime);
                                                    if (p != null) {
                                                      setSheet(() =>
                                                          endTime = p);
                                                    }
                                                  },
                                                  child: Text(
                                                    '+ 修改结束时间',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.grey[400]),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // 全天模式：重复
                                ListTile(
                                  leading: const Icon(Icons.repeat,
                                      size: 20, color: AppTheme.textSecondary),
                                  title: const Text('重复',
                                      style: TextStyle(fontSize: 15)),
                                  trailing: GestureDetector(
                                    onTap: () => _showRepeatSheet(
                                        sheetCtx,
                                        repeatRule,
                                        (v) =>
                                            setSheet(() => repeatRule = v)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_repeatLabel(repeatRule),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14)),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.grey, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const Divider(height: 1),
                              // 跳过节假日
                              SwitchListTile(
                                value: skipHolidays,
                                onChanged: (v) =>
                                    setSheet(() => skipHolidays = v),
                                title: const Text('跳过法定节假日',
                                    style: TextStyle(fontSize: 15)),
                                secondary: const Icon(
                                    Icons.celebration_outlined,
                                    size: 20,
                                    color: AppTheme.textSecondary),
                                activeThumbColor: _accent,
                                activeTrackColor:
                                    _accent.withValues(alpha: 0.4),
                              ),
                              const Divider(height: 1),
                              // 跳过周末
                              SwitchListTile(
                                value: skipWeekends,
                                onChanged: (v) =>
                                    setSheet(() => skipWeekends = v),
                                title: const Text('跳过非补班周末',
                                    style: TextStyle(fontSize: 15)),
                                secondary: const Icon(Icons.weekend_outlined,
                                    size: 20, color: AppTheme.textSecondary),
                                activeThumbColor: _accent,
                                activeTrackColor:
                                    _accent.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        ),
      );
      },
    ).whenComplete(() {
      // whenComplete 在 pop 后作为微任务立即触发，此时动画还在进行中，
      // TextField 仍挂载在树上。若此时 dispose controller，键盘关闭引起的
      // MediaQuery 变化会触发 TextField 读取已销毁的 controller → 崩溃。
      // 因此延迟到动画结束后（默认 ~250ms）再 dispose。
      Future.delayed(const Duration(milliseconds: 350), titleCtrl.dispose);
    });
  }

  // ── 辅助方法 ──────────────────────────────────────────────────

  Widget _modeBtn(
      String label, String value, String current, Function(String) onTap) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            color: sel ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext ctx, int current, List<int> options,
      Function(int) onPick) {
    showModalBottomSheet(
      context: ctx,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: options
              .map((col) => GestureDetector(
                    onTap: () {
                      onPick(col);
                      Navigator.pop(c);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(col),
                        shape: BoxShape.circle,
                        border: current == col
                            ? Border.all(color: Colors.black26, width: 3)
                            : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showRepeatSheet(
      BuildContext ctx, String current, Function(String) onSelect) {
    const options = [
      ('none', '无'),
      ('daily', '每天'),
      ('workday', '工作日'),
      ('weekly', '每周'),
      ('monthly', '每月'),
      ('yearly', '每年'),
    ];
    showModalBottomSheet(
      context: ctx,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('重复',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          ...options.map((o) => ListTile(
                title: Text(o.$2),
                trailing: current == o.$1
                    ? const Icon(Icons.check, color: _accent)
                    : null,
                onTap: () {
                  onSelect(o.$1);
                  Navigator.pop(c);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _repeatLabel(String rule) => switch (rule) {
        'daily' => '每天',
        'workday' => '工作日',
        'weekly' => '每周',
        'monthly' => '每月',
        'yearly' => '每年',
        _ => '无',
      };

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── 构建 ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final events = provider.events;
    final selectedEvents = _eventsForDate(events, _selectedDate);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部标题 ─────────────────────────────────────
            _buildHeader(),

            // ── 日历主体 ─────────────────────────────────────
            Container(
              color: AppTheme.bgCard,
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
    );
  }

  // ── 顶部标题行 ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          // 点击年份 → 年份选择器
          GestureDetector(
            onTap: _pickYear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.transparent,
              ),
              child: Text(
                '${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const Text(
            '/',
            style: TextStyle(
                fontSize: 15, color: AppTheme.textHint, fontWeight: FontWeight.bold),
          ),
          // 点击月份 → 月份选择器
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _accent.withValues(alpha: 0.08),
              ),
              child: Text(
                _currentMonth.month.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 18,
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
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: List.generate(7, (i) {
          final isWeekend = i == 0 || i == 6;
          return Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
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
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 0,
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
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(7),
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
                      fontSize: 16,
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
        const SizedBox(height: 2),
        Container(
          width: 14,
          height: 2,
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
              width: 32,
              height: 32,
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
                    fontSize: 15,
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
                right: -3,
                child: holiday.isOff
                    ? Text(
                        '休',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE53935),
                        ),
                      )
                    : Container(
                        width: 12,
                        height: 12,
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
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subLabel,
                style: TextStyle(fontSize: 8, color: subColor, height: 1.0)),
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
        color: AppTheme.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    color: AppTheme.textPrimary,
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
            const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 18),
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
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: Color(ev.colorValue), width: 4),
            ),
            boxShadow: AppTheme.cardShadow,
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
