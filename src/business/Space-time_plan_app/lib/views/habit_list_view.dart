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
                    _buildStatTab('已完成', provider.completedCount, Icons.calendar_today,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_clear, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('当前分类下没有习惯', style: TextStyle(color: Colors.grey[500])),
                        ],
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
                      onTap: () {
                        // Click card: Show "打卡成功" and `totalDays` +1
                        provider.toggleHabitCompletion(item.id, DateTime.now());
                        
                        // Show snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('打卡成功'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
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
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getFrequencyText(item),
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
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
                                    style: const TextStyle(
                                        fontSize: 22,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text(
                                    '天',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
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
