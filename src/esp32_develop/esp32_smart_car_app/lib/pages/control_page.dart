import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_settings_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  DateTime _lastMoveTime = DateTime.now();

  void _onDirectionMove(StickDragDetails details, CarState state) {
    if (!state.isConnected) return;
    final now = DateTime.now();
    if (now.difference(_lastMoveTime).inMilliseconds < 50) return;
    _lastMoveTime = now;

    // PRD: Left joystick for direction (X-axis only)
    state.sendCommand({
      "cmd": "move",
      "vx": _currentThrottle * state.maxSpeed, // Keep current throttle
      "vy": -details.x * state.maxSpeed,       // Direction (left/right)
      "vw": 0
    });
  }

  double _currentThrottle = 0.0;

  void _onThrottleMove(double value, CarState state) {
    if (!state.isConnected) return;
    _currentThrottle = value;
    
    // PRD: Right slider/joystick for throttle (vx)
    state.sendCommand({
      "cmd": "move",
      "vx": _currentThrottle * state.maxSpeed,
      "vy": 0, // In simple throttle mode, we might not want to override direction immediately
      "vw": 0
    });
  }

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
      videoUrl = "http://${state.cameraIp}:80/stream";
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Video Stream
          GestureDetector(
            onPanUpdate: (details) {
              // Convert drag to PTZ commands
              state.updateMixedServos(details.delta.dx * 0.1, details.delta.dy * 0.1);
            },
            onPanEnd: (_) => state.sendCommand({"cmd": "servo_stop", "channel": 1}),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(
                child: Mjpeg(
                  isLive: true,
                  stream: videoUrl,
                  error: (context, error, stack) => const Center(child: Icon(Icons.signal_wifi_bad, color: Colors.red, size: 50)),
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
                  
                  // Direction Joystick (Left)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30, bottom: 50),
                      child: Opacity(
                        opacity: 0.8,
                        child: Joystick(
                          mode: JoystickMode.horizontal, // PRD: Direction only
                          listener: (details) => _onDirectionMove(details, state),
                          onStickDragEnd: () => _onJoystickStop(state),
                          base: _buildJoystickBase(),
                          stick: _buildJoystickStick(),
                        ),
                      ),
                    ),
                  ),

                  // Throttle Slider (Right)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 30, bottom: 50),
                      child: Opacity(
                        opacity: 0.8,
                        child: Container(
                          height: 200,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 10,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                activeTrackColor: const Color(0xFF00F0FF),
                                inactiveTrackColor: Colors.white10,
                                thumbColor: const Color(0xFF00F0FF),
                              ),
                              child: Slider(
                                value: _currentThrottle,
                                min: -1.0,
                                max: 1.0,
                                onChanged: (val) => setState(() => _onThrottleMove(val, state)),
                                onChangeEnd: (val) {
                                  setState(() {
                                    _currentThrottle = 0;
                                    _onJoystickStop(state);
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildJoystickBase() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.5), width: 2),
      ),
    );
  }

  Widget _buildJoystickStick() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.7),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
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
           _buildActionButton(Icons.settings, Colors.white, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeviceSettingsPage()),
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
