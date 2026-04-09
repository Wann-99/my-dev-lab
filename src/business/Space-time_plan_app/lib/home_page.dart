import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:space_time_plan_app/views/add_habit_view.dart';
import 'package:space_time_plan_app/views/plan_view.dart';
import 'package:space_time_plan_app/views/habit_list_view.dart';
import 'package:space_time_plan_app/views/calendar_view.dart';
import 'package:space_time_plan_app/views/apps_view.dart';
import 'package:space_time_plan_app/views/profile_view.dart';
import 'package:space_time_plan_app/widgets/glass_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isAddHabitView = false;

  /// 通过 notifier.value++ 触发 CalendarView 弹出"添加事项"弹窗
  final _calendarAddTrigger = ValueNotifier<int>(0);

  /// 退出 App 二次确认
  bool _exitWarned = false;
  Timer? _exitTimer;

  void _onItemTapped(int index) =>
      setState(() { _selectedIndex = index; _isAddHabitView = false; });
  void _navigateToAddHabit() => setState(() => _isAddHabitView = true);
  void _navigateBackToPlan() => setState(() => _isAddHabitView = false);

  /// 处理系统返回键
  /// 返回 true 表示"允许 pop（退出）"，false 表示"拦截，不退出"
  Future<bool> _onWillPop() async {
    // 有覆盖层：关闭添加习惯页，不退出
    if (_isAddHabitView) {
      _navigateBackToPlan();
      return false;
    }

    // 主页面：二次确认退出
    if (_exitWarned) {
      // 第二次按下 → 真正退出
      _exitTimer?.cancel();
      return true;
    }

    // 第一次按下 → 提示
    setState(() => _exitWarned = true);
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _exitWarned = false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('再按一次退出应用'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      ),
    );
    return false;
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _calendarAddTrigger.dispose();
    super.dispose();
  }

  // 根据当前 tab 决定 FAB 的行为；AddHabitView 覆盖时隐藏 FAB
  VoidCallback? get _fabAction {
    if (_isAddHabitView) return null;
    switch (_selectedIndex) {
      case 0: return _navigateToAddHabit;              // 习惯 → 添加习惯
      case 1: return () => _calendarAddTrigger.value++; // 事项 → 添加事项
      case 3: return _navigateToAddHabit;              // 规划 → 添加习惯
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> views = [
      HabitListView(onAddTap: _navigateToAddHabit),
      CalendarView(addTrigger: _calendarAddTrigger),
      const AppsView(),
      PlanView(onAddTap: _navigateToAddHabit),
      const ProfileView(),
    ];

    final showFab = _fabAction != null;

    return PopScope(
      // false = 我们自己处理，不让系统直接 pop
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && context.mounted) {
          // 真正退出 App
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.bgMain,
      extendBody: true,
      floatingActionButton: showFab
          ? FloatingActionButton(
              heroTag: 'home_fab',
              backgroundColor: AppTheme.primary,
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: _fabAction,
              child: const Icon(Icons.add, size: 30, color: Colors.white),
            )
          : null,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: views),
          if (_isAddHabitView)
            Positioned.fill(
              child: Material(
                color: AppTheme.bgMain,
                child: SafeArea(
                  bottom: false,
                  child: AddHabitView(
                    onCancel: _navigateBackToPlan,
                    onSave: _navigateBackToPlan,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isAddHabitView ? null : _buildNavBar(),
      ),  // Scaffold
    );  // PopScope
  }

  // ── 清新白色底部导航栏 ────────────────────────────────────────
  Widget _buildNavBar() {
    const items = [
      _NavDef(Icons.grid_view_rounded, Icons.grid_view_outlined, '习惯'),
      _NavDef(Icons.calendar_month_rounded, Icons.calendar_month_outlined, '事项'),
      _NavDef(Icons.apps_rounded, Icons.apps_outlined, '应用'),
      _NavDef(Icons.check_circle_rounded, Icons.check_circle_outline_rounded, '规划'),
      _NavDef(Icons.person_rounded, Icons.person_outline_rounded, '我的'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(
            top: BorderSide(color: AppTheme.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(5, (i) {
              final item = items[i];
              final sel = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onItemTapped(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 选中时显示绿色小圆点
                        Stack(
                          alignment: Alignment.topRight,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: sel ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                sel ? item.active : item.normal,
                                color: sel
                                    ? AppTheme.primary
                                    : AppTheme.textHint,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: sel
                                ? AppTheme.primary
                                : AppTheme.textHint,
                          ),
                          child: Text(item.label),
                        ),
                        // 选中指示线
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: sel ? 20 : 0,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData active;
  final IconData normal;
  final String label;
  const _NavDef(this.active, this.normal, this.label);
}
