import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_config_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final double _linearSpeedFactor = 1.0;
  final double _angularSpeedFactor = 1.0;
  final double _strafeSpeedFactor = 1.0;
  
  // Motion State
  double _lastVx = 0, _lastVy = 0, _lastVw = 0;
  bool _pressUp = false;
  bool _pressDown = false;
  bool _pressLeft = false;
  bool _pressRight = false;
  
  // UI State
  bool _showPtzJoystick = false;

  void _applyMotion(CarState state) {
    if (!state.isConnected) return;
    if (state.mode != "MANUAL") return;

    final double v = state.maxSpeed * _linearSpeedFactor;
    final double w = state.maxSpeed * _angularSpeedFactor; // Angular speed (Turn)
    final double s = state.maxSpeed * _strafeSpeedFactor; // Strafe speed

    double vx = 0; // Forward/Backward
    double vy = 0; // Left/Right Strafe
    double vw = 0; // Turn

    // 1. Calculate Forward/Backward (Y-axis linear velocity)
    // In our coordinate system: +vx is forward, -vx is backward? 
    // Usually standard robotics: x=forward, y=left. 
    // Let's follow existing: "vx" was used for forward/back in previous code.
    if (_pressUp) vx += v;
    if (_pressDown) vx -= v;

    // 2. Calculate Strafe vs Turn based on combinations
    // Requirement: "Forward/Backward + Left/Right combination ... is Turn"
    // "Right side is Left/Right hollow arrows for Left/Right Translation (Strafe)"
    
    double lateralInput = 0;
    if (_pressLeft) lateralInput += 1; // Left button pressed
    if (_pressRight) lateralInput -= 1; // Right button pressed

    if (lateralInput != 0) {
      if (vx != 0) {
        // Moving Forward/Back + Lateral Input = TURN
        // If moving forward (vx > 0): Left Input -> Turn Left (+vw)
        // If moving backward (vx < 0): Left Input -> Turn Left (+vw) (Front steers left)
        vw = lateralInput * w; 
        vy = 0;
      } else {
        // Stationary + Lateral Input = STRAFE
        // Left Input -> Strafe Left (+vy)
        vy = lateralInput * s;
        vw = 0;
      }
    }

    // Update only if changed (to reduce traffic)
    if (vx != _lastVx || vy != _lastVy || vw != _lastVw) {
      _lastVx = vx; _lastVy = vy; _lastVw = vw;
      state.sendCommand({"cmd": "move", "vx": vx, "vy": vy, "vw": vw});
    } else if (vx == 0 && vy == 0 && vw == 0 && (_lastVx != 0 || _lastVy != 0 || _lastVw != 0)) {
       // Send stop once
       _lastVx = 0; _lastVy = 0; _lastVw = 0;
       state.sendCommand({"cmd": "move", "vx": 0, "vy": 0, "vw": 0});
    }
  }
 
  void _setUp(CarState state, bool v) { setState(() { _pressUp = v; }); _applyMotion(state); }
  void _setDown(CarState state, bool v) { setState(() { _pressDown = v; }); _applyMotion(state); }
  void _setLeft(CarState state, bool v) { setState(() { _pressLeft = v; }); _applyMotion(state); }
  void _setRight(CarState state, bool v) { setState(() { _pressRight = v; }); _applyMotion(state); }
 
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
        content: Text("Emergency Stop!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final String videoUrl;
    
    if (state.isRemoteMode) {
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
          // 1. Background: Video Stream
          InteractiveViewer(
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

          // 2. HUD Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  // Top Status Bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Center(child: _buildTopBar(state, primaryColor)),
                  ),
                  
                  // Debug Info (Optional)
                  Positioned(
                    top: 50, left: 16,
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

                  // Exit Button (Top Left)
                  Positioned(
                    top: 0, left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Emergency Stop Button (Top Right)
                  Positioned(
                    top: 0, right: 0,
                    child: ElevatedButton(
                      onPressed: () => _emergencyStop(state),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Icon(Icons.stop_rounded, size: 28),
                    ),
                  ),
                  
                  // Left Control: Up/Down (Forward/Back)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildArrowButton(
                            icon: Icons.keyboard_arrow_up_rounded, // Hollow-ish feel
                            onPress: () => _setUp(state, true),
                            onRelease: () => _setUp(state, false),
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 40), // Spacing
                          _buildArrowButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            onPress: () => _setDown(state, true),
                            onRelease: () => _setDown(state, false),
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Right Control: Left/Right (Strafe)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildArrowButton(
                            icon: Icons.keyboard_arrow_left_rounded,
                            onPress: () => _setLeft(state, true),
                            onRelease: () => _setLeft(state, false),
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 40), // Spacing
                          _buildArrowButton(
                            icon: Icons.keyboard_arrow_right_rounded,
                            onPress: () => _setRight(state, true),
                            onRelease: () => _setRight(state, false),
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Toolbar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildFloatingActionBar(state, primaryColor),
                  ),
                  
                  // PTZ Joystick Overlay
                  if (_showPtzJoystick)
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Joystick(
                          mode: JoystickMode.all,
                          listener: (details) {
                            // Invert Y for natural camera control (Up = Look Up)
                            state.updatePtz(details.x, -details.y);
                          },
                          base: JoystickBase(
                            decoration: JoystickBaseDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                          stick: JoystickStick(
                            decoration: JoystickStickDecoration(
                              color: primaryColor.withValues(alpha: 0.8),
                              shadowColor: primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(CarState state, Color primaryColor) {
    // Battery calculation handled in CarState
    final batteryPct = state.batteryPercentage;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHudItem(Icons.wifi, "${state.wifiSignal}dBm", state.isConnected ? primaryColor : Colors.red),
          _buildVerticalDivider(),
          _buildHudItem(
            Icons.battery_charging_full, 
            "${state.carBattery.toStringAsFixed(1)}V (${(batteryPct * 100).toInt()}%)", 
            state.carBattery > 7.4 ? Colors.green : Colors.orange
          ),
          _buildVerticalDivider(),
          _buildHudItem(Icons.speed, "${(state.maxSpeed * 100).toInt()}%", Colors.white),
          _buildVerticalDivider(),
          _buildHudItem(Icons.drive_eta, state.mode, state.mode == "MANUAL" ? primaryColor : Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildHudItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 12,
      width: 1,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onPress,
    required VoidCallback onRelease,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onPanDown: (_) => onPress(),
      onPanEnd: (_) => onRelease(),
      onPanCancel: () => onRelease(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9), // White icon
          size: 40,
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(CarState state, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6), 
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
          const SizedBox(width: 24),
          _buildActionButton(Icons.lightbulb_outline, state.isLightOn ? primaryColor : Colors.white, () => state.toggleLight()),
          const SizedBox(width: 24),
          // PTZ Toggle Button
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _showPtzJoystick ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: _buildActionButton(
              Icons.gamepad_rounded, 
              _showPtzJoystick ? primaryColor : Colors.white, 
              () {
                setState(() {
                  _showPtzJoystick = !_showPtzJoystick;
                });
              }
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton(Icons.camera_alt_outlined, Colors.white, () => _takeSnapshot()),
          const SizedBox(width: 24),
          _buildActionButton(Icons.campaign_outlined, state.isHornOn ? Colors.red : Colors.white, () => state.toggleHorn(!state.isHornOn)),
          const SizedBox(width: 24),
           _buildActionButton(Icons.settings_outlined, Colors.white, () {
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
      child: Icon(icon, color: color, size: 26),
    );
  }
}
