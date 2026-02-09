import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'home_page.dart';
import 'navigation_page.dart';
import 'control_entry_page.dart';
import 'mine_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const NavigationPage(),
    const ControlEntryPage(),
    const MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF12121A),
        selectedItemColor: const Color(0xFF00F0FF),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.home),
          BottomNavigationBarItem(icon: const Icon(Icons.map), label: l10n.navigation),
          BottomNavigationBarItem(icon: const Icon(Icons.gamepad), label: l10n.control),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.mine),
        ],
      ),
    );
  }
}
