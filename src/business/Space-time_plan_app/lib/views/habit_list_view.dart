import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/widgets/glass_card.dart';
import 'package:space_time_plan_app/utils/modal_sheet_utils.dart';
import 'package:space_time_plan_app/views/habit_detail_page.dart';

class HabitListView extends StatefulWidget {
  final VoidCallback? onAddTap;
  const HabitListView({super.key, this.onAddTap});

  @override
  State<HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends State<HabitListView>
    with SingleTickerProviderStateMixin {
  static const double _habitCardRadius = 20;

  int _currentTab = 0;

  // ── Icon 映射 ──────────────────────────────────────────────
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

  static String _freq(HabitPlan h) {
    if (h.repeatType == 'fixed') return '每天坚持';
    if (h.repeatType == 'weekly') return '每周 ${h.repeatDays.length} 天';
    return '每月打卡';
  }

  // ── 打开 Hero 详情页 ──────────────────────────────────────
  void _openDetail(HabitPlan habit) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => HabitDetailPage(
          habit: habit,
          heroTag: 'habit_icon_${habit.id}',
        ),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  // ── 打卡逻辑 ──────────────────────────────────────────────
  void _showNoteSheet(HabitPlan habit, DateTime date) {
    final provider = context.read<HabitProvider>();
    final record = provider.getHabitRecordForDate(habit.id, date);
    final ctrl =
        TextEditingController(text: record?.note ?? habit.checkInNote ?? '');
    popOpenModalBottomSheets(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('跳过',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                ),
                const Text('打卡心得',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                TextButton(
                  onPressed: () {
                    final t = ctrl.text.trim();
                    provider.updateCheckInNote(
                        habit.id, date, t.isEmpty ? null : t);
                    Navigator.pop(ctx);
                  },
                  child: const Text('保存',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 5,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                hintText: '写下今日心得（可选）',
                hintStyle: const TextStyle(
                    color: AppTheme.textHint, fontSize: 14),
                filled: true,
                fillColor: AppTheme.bgMain,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => Future.delayed(
        const Duration(milliseconds: 350), ctrl.dispose));
  }

  void _onTap(HabitPlan item, HabitProvider provider) {
    final now = DateTime.now();
    if (item.status == 2) {
      _snack('「${item.title}」已暂停', AppTheme.statusOrange);
      return;
    }
    if (!provider.isScheduledForDate(item, now)) {
      _snack('「${item.title}」今天不是打卡日', AppTheme.textSecondary);
      return;
    }
    final wasDone = provider.isHabitCompletedOnDate(item.id, now);
    provider.toggleHabitCompletion(item.id, now);
    final isDone = provider.isHabitCompletedOnDate(item.id, now);

    if (wasDone && !isDone) {
      _snack('已撤销「${item.title}」今日打卡', AppTheme.textSecondary);
      return;
    }
    final rec = provider.getHabitRecordForDate(item.id, now);
    final int target =
        (item.multiTarget && item.dailyTarget > 0) ? item.dailyTarget : 1;
    final int v = rec?.value ?? 0;
    if (isDone) {
      _snack('🎉 完成「${item.title}」$v/$target${item.unit}',
          AppTheme.primary);
    } else {
      final pct = ((v / target) * 100).round();
      _snack('进度：$v/$target${item.unit}（$pct%）', AppTheme.secondary);
    }
    if (item.autoPopup && isDone && !wasDone) {
      Future.microtask(() => _showNoteSheet(item, now));
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  // ── 习惯卡片 ──────────────────────────────────────────────
  Widget _buildCard(HabitPlan item, HabitProvider provider) {
    final color = Color(item.colorValue);
    final now = DateTime.now();
    final isScheduled = provider.isScheduledForDate(item, now);
    final record = provider.getHabitRecordForDate(item.id, now);
    final int target =
        (item.multiTarget && item.dailyTarget > 0) ? item.dailyTarget : 1;
    final int value = record?.value ?? 0;
    final double progress = (value / target).clamp(0.0, 1.0);
    final bool isDone = item.status == 1;
    final bool isPaused = item.status == 2;
    final Color stripeColor = isDone
        ? AppTheme.statusGreen
        : isPaused
            ? AppTheme.statusOrange
            : !isScheduled
                ? AppTheme.border
                : color;

    return GestureDetector(
      onTap: () => _onTap(item, provider),
      onLongPress: () => _openDetail(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(_habitCardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 图标行 ─────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero 动画源
                          Hero(
                            tag: 'habit_icon_${item.id}',
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_icon(item.iconKey),
                                  color: color, size: 22),
                            ),
                          ),
                          const Spacer(),
                          // 打卡状态圆点
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? AppTheme.statusGreen
                                  : isPaused
                                      ? AppTheme.statusOrange
                                      : !isScheduled
                                          ? AppTheme.border
                                          : color.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── 标题 ───────────────────────────────
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // ── 频率 ───────────────────────────────
                      Text(
                        _freq(item),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textHint),
                      ),

                      // ── 非打卡日提示 ────────────────────────
                      if (_currentTab == 0 && !isScheduled) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('今日无需打卡',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textHint)),
                        ),
                      ],

                      // ── 多目标进度 ──────────────────────────
                      if (item.multiTarget &&
                          _currentTab == 0 &&
                          isScheduled) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$value/$target${item.unit}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w600)),
                            Text('${(progress * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textHint)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                            minHeight: 5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── 底部：累计天数 ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.totalDays}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDone || isPaused
                                  ? AppTheme.textHint
                                  : color,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(' 天',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDone || isPaused
                                        ? AppTheme.textHint
                                        : color.withValues(alpha: 0.7))),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: AppTheme.textHint, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _HabitCardTopEdgePainter(
                  color: stripeColor,
                  radius: _habitCardRadius,
                  strokeWidth: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 统计条 ─────────────────────────────────────────────
  Widget _buildTab(
      String label, int count, IconData icon, Color color, int idx) {
    final sel = _currentTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.only(left: idx == 0 ? 0 : 8),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.10) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  sel ? color.withValues(alpha: 0.35) : AppTheme.border,
              width: sel ? 1.5 : 1,
            ),
            boxShadow:
                sel ? AppTheme.primaryShadow(color.withValues(alpha: 0.5)) : [],
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: sel ? color : AppTheme.textHint, size: 18),
              const SizedBox(height: 4),
              Text('$count',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: sel ? color : AppTheme.textPrimary)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          sel ? color : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 空状态 ─────────────────────────────────────────────────
  Widget _buildEmpty() {
    const msgs = [
      ['暂无进行中的习惯', '点击右下角 + 添加习惯'],
      ['今日还没有打卡', '完成习惯后会出现在这里'],
      ['没有已暂停的习惯', '在进行中列表操作可暂停习惯'],
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.spa_rounded,
                  size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(msgs[_currentTab][0],
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(msgs[_currentTab][1],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habits =
        provider.habits.where((h) => h.status == _currentTab).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('习惯打卡',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2)),
                      Text(
                        '坚持是最好的礼物',
                        style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 统计 Tab 行 ──────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab('进行中', provider.inProgressCount,
                      Icons.access_time_rounded,
                      AppTheme.primary, 0),
                  _buildTab('已打卡', provider.completedCount,
                      Icons.check_circle_rounded,
                      AppTheme.statusBlue, 1),
                  _buildTab('已暂停', provider.pausedCount,
                      Icons.pause_circle_rounded,
                      AppTheme.statusOrange, 2),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 列表标题 ────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    habits.isEmpty
                        ? ''
                        : '共 ${habits.length} 个习惯',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_currentTab == 0)
                    const Text('长按查看详情',
                        style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── 瀑布流主体 ───────────────────────────────
            Expanded(
              child: habits.isEmpty
                  ? _buildEmpty()
                  : MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.fromLTRB(
                          16, 0, 16, 100),
                      itemCount: habits.length,
                      itemBuilder: (_, i) =>
                          _buildCard(habits[i], provider),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 习惯卡片顶部描边：沿圆角矩形「顶边 + 两头上角圆弧」走笔（非矩形填色条）
class _HabitCardTopEdgePainter extends CustomPainter {
  _HabitCardTopEdgePainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = math.min(radius, w / 2);
    if (w <= 0 || r <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(0, r)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      );

    if (w > 2 * r) {
      path.lineTo(w - r, 0);
    }
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HabitCardTopEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
