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
      appBar: AppBar(title: Text(l10n.control), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: canControl ? () => state.emergencyStop() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.emergencyStop),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canControl
                        ? () {
                            final nextMode = state.mode == 'MANUAL' ? 'AUTO' : 'MANUAL';
                            state.setCarMode(nextMode);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      state.mode == 'MANUAL' ? l10n.switchToAuto : l10n.switchToManual,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l10n.videoPreview, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: previewHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: state.isConnected && state.cameraIp.isNotEmpty
                    ? Mjpeg(
                        key: ValueKey(
                          "ctrlEntry-${state.isRemoteMode}-${state.cameraIp}-${state.deviceId}-${state.relayServer}-${state.isConnected}",
                        ),
                        isLive: true,
                        stream: previewUrl,
                        error: (context, error, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                              const SizedBox(height: 10),
                              Text(l10n.videoError, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                            SizedBox(height: 10),
                            Text("设备未连接或摄像头IP为空", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(l10n.mode, state.mode, Icons.settings),
              _buildStatusItem(l10n.distance, "${state.distance}cm", Icons.settings_input_antenna),
              _buildStatusItem(l10n.battery, "${state.carBattery}V", Icons.battery_charging_full),
              _buildStatusItem(l10n.signal, "${state.wifiSignal}dBm", Icons.wifi),
            ],
          ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: state.isConnected && state.mode == 'MANUAL'
                    ? () async {
                        if (!state.isConnected) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                  const SizedBox(width: 10),
                                  Text(l10n.connectWarning),
                                ],
                              ),
                              content: Text(l10n.offlineWarning),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(l10n.confirm),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

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
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  backgroundColor: canControl && state.mode == 'MANUAL'
                      ? const Color(0xFF00F0FF).withValues(alpha: 0.9)
                      : Colors.grey.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                ),
                child: Text(l10n.startControl, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00F0FF), size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
