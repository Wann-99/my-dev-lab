import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';
import '../widgets/emergency_stop_button.dart';
import 'home_page.dart';
import 'device_page.dart';
import 'control_page.dart';
import 'mine_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const DevicePage(),
    const ControlPage(),
    const MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_rounded, color: Color(0xFF29B6F6)),
            const SizedBox(width: 10),
            Text(l10n.appTitle),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.wifi_rounded,
              color: state.isConnected ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: state.currentTabIndex,
            children: _pages,
          ),
          const EmergencyStopButton(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: state.currentTabIndex,
          onTap: (index) {
            state.setTabIndex(index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF29B6F6),
          unselectedItemColor: const Color(0xFF94A3B8),
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: l10n.home),
            BottomNavigationBarItem(icon: const Icon(Icons.devices_rounded), label: l10n.device),
            BottomNavigationBarItem(icon: const Icon(Icons.videogame_asset_rounded), label: l10n.control),
            BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: l10n.mine),
          ],
        ),
      ),
    );
  }
}
