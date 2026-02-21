import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'control_page.dart';
import 'package:flutter/services.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(context, state),
            const SizedBox(height: 20),
            _buildVideoPreview(context, state),
            const SizedBox(height: 20),
            _buildQuickActions(context, state),
            const SizedBox(height: 20),
            _buildSensorSection(context, state),
            const SizedBox(height: 20),
            _buildInfoGrid(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.videoPreview, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          height: 200,
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
                    isLive: true,
                    stream: 'http://${state.cameraIp}:81/stream',
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
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    final bool canControl = state.isConnected && state.isBound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                l10n.emergencyStop,
                Icons.pan_tool,
                Colors.red,
                canControl ? () => state.emergencyStop() : null,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildActionButton(
                context,
                state.mode == 'MANUAL' ? l10n.switchToAuto : l10n.switchToManual,
                state.mode == 'MANUAL' ? Icons.auto_mode : Icons.touch_app,
                Colors.orange,
                canControl ? () => state.setCarMode(state.mode == 'MANUAL' ? 'AUTO' : 'MANUAL') : null,
              ),
            ),
          ],
        ),
        if (state.isConnected && !state.isBound)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    "设备已连接，请先在“我的”页面完成绑定以解锁控制权限",
                    style: TextStyle(color: Colors.orange[300], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorSection(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sensorStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSensorItem(l10n.left, "${state.distLeft}cm", Icons.arrow_back, state.distLeft < 20 ? Colors.red : Colors.green),
            _buildSensorItem(l10n.front, "${state.distFront}cm", Icons.arrow_upward, state.distFront < 20 ? Colors.red : Colors.green),
            _buildSensorItem(l10n.right, "${state.distRight}cm", Icons.arrow_forward, state.distRight < 20 ? Colors.red : Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    
    // PRD: If not bound, show binding guide instead of connection status
    if (!state.isBound) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.withValues(alpha: 0.2), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.link_off, color: Colors.orange, size: 40),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "设备未绑定",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "请先完成设备绑定以开始使用",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to MinePage (index 2 in MainScreen)
                  // This is a bit hacky, better would be a direct navigation or state change
                  // But for now, we'll suggest going to the Mine tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("请切换到“我的”页面进行设备搜索与绑定")),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text("去绑定设备"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (state.isConnected ? Colors.green : const Color(0xFF00F0FF)).withValues(alpha: 0.2),
            Colors.transparent
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (state.isConnected ? Colors.green : const Color(0xFF00F0FF)).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                state.isConnected ? Icons.check_circle : Icons.error_outline,
                color: state.isConnected ? Colors.green : Colors.red,
                size: 40,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isConnected ? l10n.deviceOnline : l10n.deviceOffline,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      state.isConnected ? l10n.connectionNormal : l10n.pleaseConnect,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (state.isConnected) {
                      state.disconnect();
                    } else {
                      state.connect().then((success) {
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(content: Text(l10n.connectionFailed)),
                            );
                        }
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isConnected ? Colors.red.withValues(alpha: 0.8) : const Color(0xFF00F0FF).withValues(alpha: 0.8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(state.isConnected ? l10n.disconnectDevice : l10n.connectDevice),
                ),
              ),
              if (state.isConnected) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.isBound ? () async {
                      // Switch to landscape before navigating
                      await SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                      
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ControlPage()),
                        ).then((_) {
                          // Switch back to portrait when returning
                          SystemChrome.setPreferredOrientations([
                            DeviceOrientation.portraitUp,
                          ]);
                        });
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isBound ? Colors.green.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(state.isBound ? "进入驾驶舱" : "请先绑定设备", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildInfoItem(l10n.battery, "${state.carBattery}V", Icons.battery_charging_full, Colors.green),
        _buildInfoItem(l10n.distance, "${state.distance}cm", Icons.settings_input_antenna, Colors.blue),
        _buildInfoItem(l10n.mode, state.mode == 'MANUAL' ? l10n.manual : (state.mode == 'AUTO' ? l10n.auto : state.mode), Icons.settings, Colors.orange),
        _buildInfoItem(l10n.signal, "${state.wifiSignal}dBm", Icons.wifi, Colors.purple),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
