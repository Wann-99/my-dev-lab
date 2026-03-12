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
    final primaryColor = const Color(0xFF29B6F6);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: primaryColor.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Color(0xFF999999), fontSize: 12, fontWeight: FontWeight.w500);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: primaryColor, size: 26);
            }
            return const IconThemeData(color: Color(0xFF999999), size: 24);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined), 
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.home
            ),
            NavigationDestination(
              icon: const Icon(Icons.devices_outlined), 
              selectedIcon: const Icon(Icons.devices_rounded),
              label: l10n.device
            ),
            NavigationDestination(
              icon: const Icon(Icons.gamepad_outlined), 
              selectedIcon: const Icon(Icons.gamepad_rounded),
              label: l10n.control
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded), 
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.mine
            ),
          ],
        ),
      ),
    );
  }
}
