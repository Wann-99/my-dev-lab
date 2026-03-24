import 'package:flutter/material.dart';
import 'package:space_time_plan_app/views/add_habit_view.dart';
import 'package:space_time_plan_app/views/plan_view.dart';
import 'package:space_time_plan_app/views/habit_list_view.dart';
import 'package:space_time_plan_app/views/calendar_view.dart';
import 'package:space_time_plan_app/views/apps_view.dart';
import 'package:space_time_plan_app/views/profile_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Default to '习惯打卡'
  bool _isAddHabitView = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _isAddHabitView = false; // Reset to normal view when tab changes
    });
  }

  void _navigateToAddHabit() {
    setState(() {
      _isAddHabitView = true;
    });
  }

  void _navigateBackToPlan() {
    setState(() {
      _isAddHabitView = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> views = [
      HabitListView(onAddTap: _navigateToAddHabit),
      const CalendarView(),
      const AppsView(),
      PlanView(onAddTap: _navigateToAddHabit),
      const ProfileView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Main views based on bottom nav
            IndexedStack(
              index: _selectedIndex,
              children: views,
            ),
            
            // Add Habit View overlaid on top
            if (_isAddHabitView)
              Positioned.fill(
                child: AddHabitView(
                  onCancel: _navigateBackToPlan,
                  onSave: () {
                    // Logic to save habit is inside AddHabitView or passed here
                    _navigateBackToPlan();
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: !_isAddHabitView ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF5599FF),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.layers),
            label: '习惯打卡',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            label: '事项',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: '应用',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: '规划',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ) : null,
    );
  }
}
