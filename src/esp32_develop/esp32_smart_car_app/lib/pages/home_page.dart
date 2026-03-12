import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    // Light Theme Colors (Restored)
    const cardColor = Colors.white; // Glass effect handled in components if needed, or just white
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Allow gradient to show through if wrapped
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF64B5F6), // Blue 400 (Sky top)
              Color(0xFFBBDEFB), // Blue 100
              Color(0xFFF5F6FA), // Light Gray (Bottom)
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                stretch: true,
                title: Text(
                  l10n.appTitle, // "RoboCar-A"
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  )
                ),
                actions: [
                  const SizedBox(width: 8),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), // Extra bottom padding for fab/nav
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildLargeControlCard(context, state, l10n, cardColor),
                    const SizedBox(height: 16),
                    _buildDashboardGrid(context, state, l10n, cardColor),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeControlCard(BuildContext context, CarState state, AppLocalizations l10n, Color cardColor) {
    final isConnected = state.isConnected;
    final batteryPct = state.batteryPercentage;
    
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.85), // Glass effect
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, // Navigate to detail?
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Battery Ring
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: isConnected ? batteryPct : 0,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation(
                            isConnected 
                              ? (batteryPct > 0.2 ? const Color(0xFF29B6F6) : const Color(0xFFFF5252)) 
                              : Colors.transparent
                          ),
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      // Icon Container
                      Container(
                        width: 64, // Slightly smaller to fit inside ring
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F5FE), // Light Blue circle background
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isConnected ? Icons.directions_car_rounded : Icons.car_crash_rounded,
                            size: 32,
                            color: const Color(0xFF29B6F6), // Blue icon
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.device, // "Device" or "RoboCar-A"
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected ? "Connected" : "Disconnected",
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected ? "Battery: ${state.carBattery.toStringAsFixed(1)}V (${(batteryPct * 100).toInt()}%)" : "No Connection",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context, CarState state, AppLocalizations l10n, Color cardColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1, 
      children: [
        _buildSmallCard(
          "WiFi Signal", 
          "${state.wifiSignal} dBm", 
          Icons.wifi, 
          const Color(0xFF42A5F5), // Blue
          cardColor,
        ),
        _buildSmallCard(
          "Latency", 
          "${state.latency} ms", 
          Icons.timer_outlined, 
          const Color(0xFFFFB74D), // Orange
          cardColor,
        ),
        _buildSmallCard(
          l10n.distance, 
          state.distance == "--" ? "--" : "${state.distance} cm", 
          Icons.radar, 
          const Color(0xFF66BB6A), // Green
          cardColor,
        ),
        _buildSmallCard(
          l10n.mode, 
          state.mode, 
          Icons.gamepad, 
          const Color(0xFFAB47BC), // Purple
          cardColor,
        ),
      ],
    );
  }

  Widget _buildSmallCard(String title, String value, IconData icon, Color iconColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
