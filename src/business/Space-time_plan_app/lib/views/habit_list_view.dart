import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/models/habit.dart';

class HabitListView extends StatefulWidget {
  final VoidCallback? onAddTap;

  const HabitListView({super.key, this.onAddTap});

  @override
  State<HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends State<HabitListView> {
  int _currentTab = 0; // 0: Ongoing, 1: Completed, 2: Paused

  void _showCheckInNoteBottomSheet(HabitPlan habit, DateTime date) {
    final provider = context.read<HabitProvider>();
    final record = provider.getHabitRecordForDate(habit.id, date);
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
                      provider.updateCheckInNote(habit.id, date, text.isEmpty ? null : text);
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

  // A helper to get icon from string key
  IconData _getIconData(String key) {
    switch (key) {
      case 'book':
      case 'library_books':
      case 'menu_book':
        return Icons.menu_book;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'directions_run':
        return Icons.directions_run;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'face':
        return Icons.face;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'favorite':
        return Icons.favorite;
      case 'music_note':
        return Icons.music_note;
      case 'brush':
        return Icons.brush;
      default:
        return Icons.star;
    }
  }

  String _getFrequencyText(HabitPlan plan) {
    if (plan.repeatType == 'fixed') {
      return '每天';
    } else if (plan.repeatType == 'weekly') {
      return '每周${plan.repeatDays.length}天';
    } else {
      return '每月';
    }
  }

  void _onHabitListTap(BuildContext context, HabitPlan item, HabitProvider provider) {
    final now = DateTime.now();

    // 已暂停：只提示，不允许打卡
    if (item.status == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${item.title}」已暂停，请先从菜单「恢复为进行中」后再打卡'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 今日非打卡日：只提示，不允许打卡
    if (!provider.isScheduledForDate(item, now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${item.title}」今天不是打卡日'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 进行中 & 今日已打卡 均可点击切换（撤销/打卡）
    final bool wasCompletedBefore = provider.isHabitCompletedOnDate(item.id, now);
    provider.toggleHabitCompletion(item.id, now);
    final bool isCompletedNow = provider.isHabitCompletedOnDate(item.id, now);

    // 撤销打卡
    if (wasCompletedBefore && !isCompletedNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已撤销「${item.title}」今日打卡'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // 打卡进度提示
    final record = provider.getHabitRecordForDate(item.id, now);
    final int target = item.multiTarget ? item.dailyTarget : 1;
    final int safeTarget = target <= 0 ? 1 : target;
    final int value = record?.value ?? 0;
    final int safeValue = value > safeTarget ? safeTarget : value;
    final int percent = ((safeValue / safeTarget) * 100).round();
    final String unit = item.unit;
    final String msg = isCompletedNow
        ? '已完成 ${item.title}：$safeValue/$safeTarget$unit'
        : '打卡进度：$safeValue/$safeTarget$unit ($percent%)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );

    // 首次达成每日目标且开启了 autoPopup，弹出心得
    if (item.autoPopup && isCompletedNow && !wasCompletedBefore) {
      Future.microtask(() => _showCheckInNoteBottomSheet(item, now));
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    
    // Filter habits based on current tab using the status field from HabitPlan
    final allHabits = provider.habits;
    final displayHabits = allHabits.where((h) => h.status == _currentTab).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          '习惯打卡',
          style: TextStyle(
              color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Stats Tabs
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatTab('进行中', provider.inProgressCount,
                        Icons.access_time, const Color(0xFF44CC88), _currentTab == 0, 0),
                    _buildStatTab('今日已打卡', provider.completedCount, Icons.check_circle,
                        const Color(0xFF5599FF), _currentTab == 1, 1),
                    _buildStatTab('已暂停', provider.pausedCount, Icons.pause_circle_outline,
                        const Color(0xFFFF9933), _currentTab == 2, 2),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Habit List
              Expanded(
                child: displayHabits.isEmpty 
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_clear, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            _currentTab == 0
                                ? '还没有进行中的习惯'
                                : _currentTab == 1
                                    ? '今日还没有已打卡的习惯'
                                    : '暂无已暂停的习惯',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentTab == 0
                                ? '点击右下角 + 添加；进行中习惯可通过菜单暂停或手动标记今日已打卡。'
                                : _currentTab == 1
                                    ? '当日打卡完成后习惯会自动出现在这里，次日自动回到「进行中」。'
                                    : '在「进行中」列表点 ⋮ 选择「暂停」后，习惯会出现在这里；恢复时会重置为初始状态。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                      ),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8)
                      .copyWith(bottom: 80), // Space for FAB
                  itemCount: displayHabits.length,
                  itemBuilder: (context, index) {
                    final item = displayHabits[index];

                    return GestureDetector(
                      onTap: () => _onHabitListTap(context, item, provider),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(item.colorValue),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getIconData(item.iconKey),
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            
                            // Title & Frequency
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: _currentTab == 0
                                            ? Colors.black
                                            : Colors.black.withValues(alpha: 0.78),
                                        fontWeight: FontWeight.bold,
                                        decoration: _currentTab != 0
                                            ? TextDecoration.none
                                            : null),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFrequencyText(item),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                  // 今日非打卡日提示
                                  if (_currentTab == 0 && !provider.isScheduledForDate(item, DateTime.now())) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '今日不是打卡日',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                  ],
                                  // 多目标进度条（仅进行中且是打卡日的习惯显示）
                                  if (item.multiTarget && _currentTab == 0 && provider.isScheduledForDate(item, DateTime.now())) ...[
                                    const SizedBox(height: 8),
                                    Builder(builder: (context) {
                                      final record = provider.getHabitRecordForDate(
                                          item.id, DateTime.now());
                                      final int target =
                                          item.dailyTarget <= 0 ? 1 : item.dailyTarget;
                                      final int value = record?.value ?? 0;
                                      final double progress =
                                          (value / target).clamp(0.0, 1.0);
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.grey[200],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(item.colorValue)),
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$value/$target${item.unit}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500]),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                  if (_currentTab == 1) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '今日已打卡完成，点击可撤销',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.blue[600]),
                                    ),
                                  ],
                                  if (_currentTab == 2) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '已暂停，恢复时将重置今日进度',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.orange[800]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            // Accumulated Days
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${item.totalDays}',
                                      style: TextStyle(
                                          fontSize: 22,
                                          color: _currentTab == 0 ? Colors.black : Colors.black.withValues(alpha: 0.65),
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '天',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: _currentTab == 0 ? Colors.black : Colors.black.withValues(alpha: 0.65),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '累计打卡',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Floating Action Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'habit_add',
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

  Widget _buildStatTab(String title, int count, IconData icon, Color color,
      bool isSelected, int tabIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = tabIndex;
        });
      },
      child: Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                  color: isSelected ? Colors.grey[800] : Colors.grey[500],
                  fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black87 : color),
        ),
        const SizedBox(height: 4),
        if (isSelected)
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          const SizedBox(height: 3),
      ],
    ),
    );
  }
}
