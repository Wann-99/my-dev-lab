import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/models/habit_record.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/widgets/glass_card.dart';

class HabitDetailPage extends StatefulWidget {
  final HabitPlan habit;
  final String heroTag;

  const HabitDetailPage({
    super.key,
    required this.habit,
    required this.heroTag,
  });

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static IconData _icon(String key) {
    const m = {
      'book': Icons.menu_book_rounded,
      'library_books': Icons.menu_book_rounded,
      'menu_book': Icons.menu_book_rounded,
      'cleaning_services': Icons.cleaning_services_rounded,
      'wb_sunny': Icons.wb_sunny_rounded,
      'directions_run': Icons.directions_run_rounded,
      'local_cafe': Icons.local_cafe_rounded,
      'self_improvement': Icons.self_improvement_rounded,
      'face': Icons.face_rounded,
      'fitness_center': Icons.fitness_center_rounded,
      'favorite': Icons.favorite_rounded,
      'music_note': Icons.music_note_rounded,
      'brush': Icons.brush_rounded,
    };
    return m[key] ?? Icons.star_rounded;
  }

  static String _repeatText(HabitPlan h) {
    if (h.repeatType == 'fixed') return '每天坚持';
    if (h.repeatType == 'weekly') {
      const days = ['一', '二', '三', '四', '五', '六', '日'];
      final ds = h.repeatDays.map((d) => '周${days[d - 1]}').join('、');
      return '每周 $ds';
    }
    return '每月 ${h.repeatDays.join('、')} 日';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habit = provider.habits.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => widget.habit,
    );
    final now = DateTime.now();
    final record = provider.getHabitRecordForDate(habit.id, now);
    final int target =
        habit.multiTarget && habit.dailyTarget > 0 ? habit.dailyTarget : 1;
    final int value = record?.value ?? 0;
    final double progress = (value / target).clamp(0.0, 1.0);
    final color = Color(habit.colorValue);
    final bool isScheduled = provider.isScheduledForDate(habit, now);
    final bool isDone = habit.status == 1;
    final bool isPaused = habit.status == 2;

    final last7 = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
    final List<CheckInLog?> logs =
        last7.map((d) => provider.getHabitRecordForDate(habit.id, d)).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('习惯详情',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 顶部 Hero 主卡 ─────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      // Hero 图标圆
                      Hero(
                        tag: widget.heroTag,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon(habit.iconKey),
                              color: color, size: 38),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        habit.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSecondary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _repeatText(habit),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 状态徽章
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badge(
                            isPaused
                                ? '已暂停'
                                : isDone
                                    ? '今日已打卡'
                                    : '进行中',
                            isPaused
                                ? AppTheme.statusOrange
                                : isDone
                                    ? AppTheme.statusGreen
                                    : color,
                          ),
                          if (!isScheduled && !isPaused) ...[
                            const SizedBox(width: 8),
                            _badge('今日无需打卡', AppTheme.textHint),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 三列统计 ─────────────────────────────────
                Row(
                  children: [
                    _statCard('累计打卡', '${habit.totalDays}', '天', color),
                    const SizedBox(width: 10),
                    _statCard(
                        '今日目标',
                        '${habit.multiTarget ? habit.dailyTarget : 1}',
                        habit.unit,
                        AppTheme.secondary),
                    const SizedBox(width: 10),
                    _statCard(
                        '时段',
                        habit.timeOfDay.isEmpty ? '全天' : habit.timeOfDay,
                        '',
                        AppTheme.statusOrange),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 今日进度 ─────────────────────────────────
                if (!isPaused && isScheduled)
                  _sectionCard(
                    title: '今日进度',
                    trailing: Text('$value / $target ${habit.unit}',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                color.withValues(alpha: 0.10),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isDone ? '🎉 今日目标已完成！' : '继续加油！',
                              style: TextStyle(
                                  color: isDone
                                      ? AppTheme.statusGreen
                                      : AppTheme.textSecondary,
                                  fontSize: 13),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (!isPaused && isScheduled) const SizedBox(height: 16),

                // ── 近7天 ────────────────────────────────────
                _sectionCard(
                  title: '近 7 天',
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final d = last7[i];
                          final log = logs[i];
                          final checked = log?.isCompleted == true;
                          final isToday =
                              d == DateTime(now.year, now.month, now.day);
                          return Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: checked
                                      ? color.withValues(alpha: 0.15)
                                      : AppTheme.bgSecondary,
                                  shape: BoxShape.circle,
                                  border: isToday
                                      ? Border.all(
                                          color: color, width: 2)
                                      : Border.all(
                                          color: AppTheme.border, width: 1),
                                ),
                                child: Icon(
                                  checked
                                      ? Icons.check_rounded
                                      : Icons.remove_rounded,
                                  color: checked
                                      ? color
                                      : AppTheme.textHint,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text('${d.day}',
                                  style: TextStyle(
                                    color: isToday
                                        ? color
                                        : AppTheme.textHint,
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 今日心得 ─────────────────────────────────
                if (record?.note != null && record!.note!.isNotEmpty)
                  _sectionCard(
                    title: '今日心得',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(record.note ?? '',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                height: 1.6)),
                      ],
                    ),
                  ),
                if (record?.note != null && record!.note!.isNotEmpty)
                  const SizedBox(height: 16),

                // ── 操作按钮 ─────────────────────────────────
                if (!isPaused && isScheduled)
                  _checkInButton(context, provider, habit, now, isDone, color),
                if (isPaused) _resumeButton(context, provider, habit),
                if (!isScheduled && !isPaused)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('今天不是打卡日，休息一下吧 😊',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _statCard(
          String label, String value, String unit, Color color) =>
      Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: value,
                      style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  if (unit.isNotEmpty)
                    TextSpan(
                        text: unit,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.7),
                            fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _sectionCard(
      {required String title,
      required Widget child,
      Widget? trailing}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (trailing != null) trailing,
              ],
            ),
            child,
          ],
        ),
      );

  Widget _checkInButton(BuildContext ctx, HabitProvider provider,
      HabitPlan habit, DateTime now, bool isDone, Color color) {
    final messenger = ScaffoldMessenger.of(ctx);
    return GestureDetector(
      onTap: () {
        provider.toggleHabitCompletion(habit.id, now);
        if (!isDone && habit.autoPopup) {
          Future.microtask(() {
            if (!mounted) return;
            messenger.showSnackBar(SnackBar(
              content: Text(isDone ? '已撤销今日打卡' : '🎉 打卡成功！'),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          });
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isDone ? AppTheme.bgSecondary : color,
          borderRadius: BorderRadius.circular(16),
          border: isDone
              ? Border.all(color: AppTheme.border, width: 1.2)
              : null,
          boxShadow: isDone ? [] : AppTheme.primaryShadow(color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone
                  ? Icons.undo_rounded
                  : Icons.check_circle_outline_rounded,
              color: isDone ? AppTheme.textSecondary : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isDone ? '撤销今日打卡' : '立即打卡',
              style: TextStyle(
                  color:
                      isDone ? AppTheme.textSecondary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumeButton(
      BuildContext ctx, HabitProvider provider, HabitPlan habit) =>
      GestureDetector(
        onTap: () {
          provider.setHabitStatus(habit.id, 0);
          Navigator.pop(ctx);
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.statusOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.primaryShadow(AppTheme.statusOrange),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text('恢复为进行中',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      );
}
