import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_config_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  double _currentThrottle = 0.0;
  double _linearSpeedFactor = 1.0;
  double _angularSpeedFactor = 1.0;
  double _strafeSpeedFactor = 1.0;
  double _lastVx = 0, _lastVy = 0, _lastVw = 0;
  bool _pressFwd = false;
  bool _pressBack = false;
  bool _pressLeft = false;
  bool _pressRight = false;
  bool _pressStrafeLeft = false;
  bool _pressStrafeRight = false;
  Timer? _uTurnTimer;

  void _onJoystickStop(CarState state) {
    if (!state.isConnected) return;
    _currentThrottle = 0;
    state.sendCommand({
      "cmd": "move",
      "vx": 0,
      "vy": 0,
      "vw": 0
    });
  }

  void _applyMotion(CarState state) {
    if (!state.isConnected) return;
    if (state.mode != "MANUAL") return;
    if (_uTurnTimer != null) return; // u-turn中，忽略组合键
    final double v = state.maxSpeed * _linearSpeedFactor;
    final double w = state.maxSpeed * _angularSpeedFactor;
    final double s = state.maxSpeed * _strafeSpeedFactor;
    double vx = 0, vy = 0, vw = 0;
    if (_pressFwd) vx += v;
    if (_pressBack) vx -= v;
    if (_pressStrafeRight) vy += s;
    if (_pressStrafeLeft) vy -= s;
    if (_pressLeft) vw += w;
    if (_pressRight) vw -= w;
    _lastVx = vx; _lastVy = vy; _lastVw = vw;
    if (vx == 0 && vy == 0 && vw == 0) {
      state.sendCommand({"cmd": "move", "vx": 0, "vy": 0, "vw": 0});
    } else {
      state.sendCommand({"cmd": "move", "vx": vx, "vy": vy, "vw": vw});
    }
  }
 
  void _setFwd(CarState state, bool v) { setState(() { _pressFwd = v; }); _applyMotion(state); }
  void _setBack(CarState state, bool v) { setState(() { _pressBack = v; }); _applyMotion(state); }
  void _setLeft(CarState state, bool v) { setState(() { _pressLeft = v; }); _applyMotion(state); }
  void _setRight(CarState state, bool v) { setState(() { _pressRight = v; }); _applyMotion(state); }
  void _setStrafeLeft(CarState state, bool v) { setState(() { _pressStrafeLeft = v; }); _applyMotion(state); }
  void _setStrafeRight(CarState state, bool v) { setState(() { _pressStrafeRight = v; }); _applyMotion(state); }
 
  void _stopMove(CarState state) {
    if (!state.isConnected) return;
    state.sendCommand({"cmd": "move", "vx": 0, "vy": 0, "vw": 0});
  }

  Future<void> _uTurn(CarState state, bool left) async {
    if (!state.isConnected) return;
    if (state.mode != "MANUAL") return;
    _uTurnTimer?.cancel();
    final w = state.maxSpeed * _angularSpeedFactor;
    state.sendCommand({"cmd": "move", "vx": 0, "vy": 0, "vw": left ? w : -w});
    _uTurnTimer = Timer(const Duration(milliseconds: 900), () {
      _uTurnTimer = null;
      _applyMotion(state);
    });
  }

  void _emergencyStop(CarState state) {
    state.sendCommand({
      "cmd": "move",
      "vx": 0,
      "vy": 0,
      "vw": 0
    });
    // Visual feedback for emergency stop
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("紧急制动！", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _takeSnapshot() async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<CarState>();
    String cameraIp = state.cameraIp;
    if (cameraIp.isEmpty && !state.isRemoteMode) return;

    if (Platform.isAndroid) {
       var status = await Permission.storage.status;
       if (!status.isGranted) await Permission.storage.request();
    }

    try {
      final String captureUrl;
      if (state.isRemoteMode) {
        // Use relay server for snapshot (we need to add a proxy for capture too or use stream)
        // For simplicity, let's assume the relay server handles /capture too.
        String host = state.relayServer;
        if (!host.startsWith('http://') && !host.startsWith('https://')) {
          host = 'http://$host';
        }
        captureUrl = "$host/capture/${state.deviceId}?ip=$cameraIp";
      } else {
        captureUrl = "http://$cameraIp/capture";
      }
      
      final response = await http.get(Uri.parse(captureUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await Gal.putImageBytes(response.bodyBytes, name: "smart_car_${DateTime.now().millisecondsSinceEpoch}");
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(l10n.snapshotSaved), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.error(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final String videoUrl;
    
    if (state.isRemoteMode) {
      // Use relay server for video stream
      String host = state.relayServer;
      if (!host.startsWith('http://') && !host.startsWith('https://')) {
        host = 'http://$host';
      }
      videoUrl = "$host/stream/${state.deviceId}?ip=${state.cameraIp}";
    } else {
      videoUrl = "http://${state.cameraIp}:81/stream";
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Video Stream
          GestureDetector(
            onPanUpdate: state.mode == "MANUAL"
                ? (details) {
                    state.updateMixedServos(details.delta.dx * 0.1, details.delta.dy * 0.1);
                  }
                : null,
            onPanEnd: state.mode == "MANUAL"
                ? (_) => state.sendCommand({"cmd": "servo_stop", "channel": 1})
                : null,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: SizedBox.expand(
                child: Mjpeg(
                  key: ValueKey(
                    "control-${state.isRemoteMode}-${state.cameraIp}-${state.deviceId}-${state.relayServer}-${state.isConnected}",
                  ),
                  isLive: true,
                  stream: videoUrl,
                  error: (context, error, stack) => const Center(
                    child: Icon(Icons.signal_wifi_bad, color: Colors.red, size: 50),
                  ),
                ),
              ),
            ),
          ),

          // HUD Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  // Top Status Bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: _buildTopBar(state),
                  ),
          Positioned(
            top: 40, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "vx:${_lastVx.toStringAsFixed(2)} vy:${_lastVy.toStringAsFixed(2)} vw:${_lastVw.toStringAsFixed(2)}",
                style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),

                  // Exit Button
                  Positioned(
                    top: 0, left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Emergency Stop Button (PRD: High Priority)
                  Positioned(
                    top: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () => _emergencyStop(state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text("STOP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ),
                  
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: _buildDirectionPad(state),
                    ),
                  ),

                  // Bottom Action Bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildFloatingActionBar(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(CarState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHudItem(Icons.wifi, "${state.wifiSignal}dBm", state.isConnected ? const Color(0xFF00F0FF) : Colors.red),
          _buildVerticalDivider(),
          _buildHudItem(Icons.battery_charging_full, "${state.carBattery}V", state.carBattery > 11.0 ? Colors.green : Colors.orange),
          _buildVerticalDivider(),
          _buildHudItem(Icons.speed, "${(state.maxSpeed * 100).toInt()}%", Colors.white),
          _buildVerticalDivider(),
          _buildHudItem(Icons.settings_input_antenna, "${state.distance}cm", Colors.yellow),
          _buildVerticalDivider(),
          _buildHudItem(Icons.drive_eta, state.mode, state.mode == "MANUAL" ? const Color(0xFF00F0FF) : Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildHudItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 15,
      width: 1,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildDirectionPad(CarState state) {
    final bool enabled = state.isConnected && state.mode == "MANUAL";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：上排=原地左/右转, 下排=平移左/右
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildHoldButton(
                  icon: Icons.rotate_left,
                  onPress: enabled ? () => _setLeft(state, true) : null,
                  onRelease: enabled ? () => _setLeft(state, false) : null,
                ),
                const SizedBox(width: 12),
                _buildHoldButton(
                  icon: Icons.rotate_right,
                  onPress: enabled ? () => _setRight(state, true) : null,
                  onRelease: enabled ? () => _setRight(state, false) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildHoldButton(
                  icon: Icons.chevron_left,
                  onPress: enabled ? () => _setStrafeLeft(state, true) : null,
                  onRelease: enabled ? () => _setStrafeLeft(state, false) : null,
                ),
                const SizedBox(width: 12),
                _buildHoldButton(
                  icon: Icons.chevron_right,
                  onPress: enabled ? () => _setStrafeRight(state, true) : null,
                  onRelease: enabled ? () => _setStrafeRight(state, false) : null,
                ),
              ],
            ),
          ],
        ),
        // 中间：左右调头（水平排列）
        Row(
          children: [
            _buildHoldButton(
              icon: Icons.subdirectory_arrow_left,
              onPress: enabled ? () => _uTurn(state, true) : null,
              onRelease: enabled ? () => _stopMove(state) : null,
            ),
            const SizedBox(width: 12),
            _buildHoldButton(
              icon: Icons.subdirectory_arrow_right,
              onPress: enabled ? () => _uTurn(state, false) : null,
              onRelease: enabled ? () => _stopMove(state) : null,
            ),
          ],
        ),
        // 右侧：前进/后退（垂直列）
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHoldButton(
              icon: Icons.arrow_upward,
              onPress: enabled ? () => _setFwd(state, true) : null,
              onRelease: enabled ? () => _setFwd(state, false) : null,
            ),
            const SizedBox(height: 12),
            _buildHoldButton(
              icon: Icons.arrow_downward,
              onPress: enabled ? () => _setBack(state, true) : null,
              onRelease: enabled ? () => _setBack(state, false) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHoldButton({
    required IconData icon,
    required VoidCallback? onPress,
    required VoidCallback? onRelease,
  }) {
    final bool isEnabled = onPress != null && onRelease != null;
    return Listener(
      onPointerDown: (_) {
        if (isEnabled) onPress();
      },
      onPointerUp: (_) {
        if (isEnabled) onRelease();
      },
      onPointerCancel: (_) {
        if (isEnabled) onRelease();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.black45 : Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00F0FF).withValues(alpha: isEnabled ? 0.8 : 0.2),
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled ? const Color(0xFF00F0FF) : Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(CarState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54, 
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            state.mode == "MANUAL" ? Icons.auto_fix_off : Icons.auto_fix_high, 
            state.mode == "MANUAL" ? Colors.white : Colors.purpleAccent, 
            () {
              final nextMode = state.mode == "MANUAL" ? "AUTO" : "MANUAL";
              state.setCarMode(nextMode);
            }
          ),
          const SizedBox(width: 20),
          _buildActionButton(Icons.lightbulb, state.isLightOn ? const Color(0xFF00F0FF) : Colors.white, () => state.toggleLight()),
          const SizedBox(width: 20),
          _buildActionButton(Icons.camera_alt, Colors.white, () => _takeSnapshot()),
          const SizedBox(width: 20),
          _buildActionButton(Icons.campaign, state.isHornOn ? Colors.red : Colors.white, () => state.toggleHorn(!state.isHornOn)),
          const SizedBox(width: 20),
          _buildActionButton(
            state.isCamFlashOn ? Icons.flash_on : Icons.flash_off, 
            state.isCamFlashOn ? Colors.amber : Colors.white, 
            () => state.toggleCamFlash()
          ),
          const SizedBox(width: 20),
           _buildActionButton(Icons.settings, Colors.white, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeviceConfigPage()),
              );
           }),
         ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 28),
    );
  }
}
