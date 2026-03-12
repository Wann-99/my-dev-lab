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
    final bool canControl = state.isConnected;

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
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white)
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
                          flex: 2,
                          child: _buildControlCard(
                            context,
                            l10n.emergencyStop,
                            Icons.warning_rounded,
                            Colors.redAccent,
                            canControl ? () => state.emergencyStop() : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildModeToggleCard(context, state, l10n),
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
                    const SizedBox(height: 32),
                    _buildStartControlButton(context, state, l10n),
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85), // Glass
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggleCard(BuildContext context, CarState state, AppLocalizations l10n) {
    final isManual = state.mode == 'MANUAL';
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 32,
                  child: Switch(
                    value: isManual,
                    onChanged: state.isConnected 
                      ? (v) => state.setCarMode(v ? 'MANUAL' : 'AUTO')
                      : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isManual ? l10n.manual : l10n.auto,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          _buildStatusItem(l10n.battery, "${state.carBattery}V", Icons.battery_charging_full_rounded, const Color(0xFFFFB74D)),
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

  Widget _buildStartControlButton(BuildContext context, CarState state, AppLocalizations l10n) {
    final bool canStart = state.isConnected && state.mode == 'MANUAL';
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canStart ? () async {
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
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: canStart ? primaryColor : const Color(0xFFF5F5F5),
          foregroundColor: canStart ? Colors.white : const Color(0xFFCCCCCC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: canStart ? 4 : 0,
          shadowColor: primaryColor.withValues(alpha: 0.4),
        ),
        child: Text(
          l10n.startControl.toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
