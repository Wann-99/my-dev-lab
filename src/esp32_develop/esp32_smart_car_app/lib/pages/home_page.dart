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
                  l10n.appTitle, 
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
                    _buildLargeControlCard(context, state, l10n),
                    const SizedBox(height: 16),
                    _buildDashboardGrid(context, state, l10n),
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

  Widget _buildLargeControlCard(BuildContext context, CarState state, AppLocalizations l10n) {
    final isConnected = state.isConnected;
    
    // Battery calculation (Assume 3S LiPo: 10.5V - 12.6V)
    double batteryPct = 0.0;
    if (state.carBattery > 0) {
      batteryPct = ((state.carBattery - 10.5) / (12.6 - 10.5)).clamp(0.0, 1.0);
    }
    
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85), // Glass effect
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
            padding: const EdgeInsets.all(20),
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
                          color: isConnected ? const Color(0xFFE1F5FE) : const Color(0xFFFFEBEE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConnected ? Icons.directions_car_rounded : Icons.car_crash_rounded,
                          size: 32,
                          color: isConnected ? const Color(0xFF29B6F6) : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.device, // "RoboCar-A"
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected ? l10n.deviceOnline : l10n.deviceOffline,
                        style: TextStyle(
                          fontSize: 14,
                          color: isConnected ? const Color(0xFF29B6F6) : const Color(0xFFFF5252),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected ? "${l10n.battery} ${state.carBattery}V (${(batteryPct * 100).toInt()}%)" : l10n.pleaseConnect,
                        style: const TextStyle(
                          fontSize: 12,
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

  Widget _buildDashboardGrid(BuildContext context, CarState state, AppLocalizations l10n) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5, // Wider cards like Mi Home small cards
      children: [
        _buildSmallCard(
          l10n.signal, 
          "${state.wifiSignal} dBm", 
          Icons.wifi_rounded, 
          const Color(0xFF42A5F5),
          state.isConnected,
        ),
        _buildSmallCard(
          l10n.distance, 
          "${state.distance} cm", 
          Icons.radar_rounded, 
          const Color(0xFF66BB6A),
          state.isConnected,
        ),
        _buildSmallCard(
          l10n.mode, 
          state.mode == 'MANUAL' ? l10n.manual : l10n.auto, 
          Icons.settings_remote_rounded, 
          const Color(0xFFAB47BC),
          state.isConnected,
        ),
        _buildSmallCard(
          "Camera", 
          state.cameraIp.isNotEmpty ? "Online" : "Offline", 
          Icons.videocam_rounded, 
          const Color(0xFFFF7043),
          state.isConnected,
        ),
      ],
    );
  }

  Widget _buildSmallCard(String title, String value, IconData icon, Color color, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: isEnabled ? color : const Color(0xFFCCCCCC), size: 28),
              if (!isEnabled)
                const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFCCCCCC)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isEnabled ? const Color(0xFF666666) : const Color(0xFFCCCCCC),
                  fontSize: 12,
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
