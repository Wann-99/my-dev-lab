import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'control_page.dart';

class ControlEntryPage extends StatelessWidget {
  const ControlEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    final String previewUrl;
    if (state.isRemoteMode) {
      String host = state.relayServer;
      if (!host.startsWith('http://') && !host.startsWith('https://')) {
        host = 'http://$host';
      }
      previewUrl = "$host/stream/${state.deviceId}?ip=${state.cameraIp}";
    } else {
      previewUrl = state.cameraIp.isNotEmpty ? 'http://${state.cameraIp}:81/stream' : '';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final previewHeight = screenWidth * 9 / 16;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF64B5F6), // Blue 400
              Color(0xFFBBDEFB), // Blue 100
              Color(0xFFF5F6FA), // Light Gray
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
                title: Text(
                  l10n.control, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5, 
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  )
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                stretch: true,
                pinned: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Extra bottom padding
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildModeToggleCard(context, state, l10n),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildTopStartControlButton(context, state, l10n),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        l10n.videoPreview, 
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 1)
                      ),
                    ),
                    _buildVideoContainer(context, state, previewUrl, previewHeight, l10n),
                    const SizedBox(height: 24),
                    _buildStatusGrid(context, state, l10n),
                    const SizedBox(height: 100), // Padding bottom for scroll
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStartControlButton(BuildContext context, CarState state, AppLocalizations l10n) {
    final bool canStart = state.isConnected && state.mode == 'MANUAL';
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return InkWell(
      onTap: canStart ? () async {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ControlPage()),
          ).then((_) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          });
        }
      } : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: canStart ? primaryColor : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: canStart ? primaryColor.withValues(alpha: 0.3) : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill_rounded, color: canStart ? Colors.white : Colors.grey, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.startControl,
              style: TextStyle(
                color: canStart ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggleCard(BuildContext context, CarState state, AppLocalizations l10n) {
    final isAuto = state.mode == 'AUTO';
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return InkWell(
      onTap: state.isConnected 
        ? () => state.setCarMode(isAuto ? 'MANUAL' : 'AUTO')
        : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85), // Glass
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAuto ? l10n.auto : l10n.manual,
              style: TextStyle(
                color: isAuto ? primaryColor : Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            IgnorePointer( // Ignore pointer for switch so InkWell handles tap
              child: Switch(
                value: isAuto,
                onChanged: (_) {}, // Handled by InkWell
                activeThumbColor: Colors.white,
                activeTrackColor: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContainer(BuildContext context, CarState state, String url, double height, AppLocalizations l10n) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: state.isConnected && state.cameraIp.isNotEmpty
            ? Mjpeg(
                key: ValueKey("ctrlEntry-${state.isRemoteMode}-${state.cameraIp}-${state.deviceId}-${state.relayServer}-${state.isConnected}"),
                isLive: true,
                stream: url,
                error: (context, error, stack) => _buildVideoError(l10n),
              )
            : _buildVideoPlaceholder(l10n),
      ),
    );
  }

  Widget _buildVideoError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(l10n.videoError, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 56),
          const SizedBox(height: 16),
          Text(
            l10n.pleaseConnect, 
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context, CarState state, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85), // Glass
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(l10n.mode, state.mode == 'MANUAL' ? l10n.manual : l10n.auto, Icons.grid_view_rounded, const Color(0xFF29B6F6)),
          _buildStatusItem(l10n.distance, "${state.distance}cm", Icons.radar_rounded, const Color(0xFF66BB6A)),
          _buildStatusItem(l10n.battery, "${state.carBattery.toStringAsFixed(1)}V", Icons.battery_charging_full_rounded, const Color(0xFFFFB74D)),
          _buildStatusItem(l10n.signal, "${state.wifiSignal}dBm", Icons.wifi_rounded, const Color(0xFFAB47BC)),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF333333))),
        Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
