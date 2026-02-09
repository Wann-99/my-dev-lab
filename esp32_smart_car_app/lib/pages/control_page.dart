import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  DateTime _lastMoveTime = DateTime.now();

  void _onJoystickMove(StickDragDetails details, CarState state) {
    final now = DateTime.now();
    if (now.difference(_lastMoveTime).inMilliseconds < 50) return;
    _lastMoveTime = now;

    state.sendCommand({
      "cmd": "move",
      "vx": -details.y * state.maxSpeed,
      "vy": -details.x * state.maxSpeed,
      "vw": 0
    });
  }

  void _onJoystickStop(CarState state) {
    state.sendCommand({
      "cmd": "move",
      "vx": 0,
      "vy": 0,
      "vw": 0
    });
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
                      icon: const Icon(Icons.close, color: Colors.white70, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  
                  // Movement Joystick
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30, bottom: 50),
                      child: Opacity(
                        opacity: 0.8,
                        child: Joystick(
                          mode: JoystickMode.all,
                          listener: (details) => _onJoystickMove(details, state),
                          onStickDragEnd: () => _onJoystickStop(state),
                          base: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.5), width: 2),
                            ),
                          ),
                          stick: Container(
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
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Align(
                    alignment: Alignment.bottomRight,
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, color: state.isConnected ? const Color(0xFF00F0FF) : Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(state.isConnected ? l10n.online : l10n.offline, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.settings, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(state.mode == 'MANUAL' ? l10n.manual : (state.mode == 'AUTO' ? l10n.auto : state.mode), style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.battery_4_bar, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text("${state.carBattery}V", style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar(CarState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(Icons.lightbulb, state.isLightOn ? const Color(0xFF00F0FF) : Colors.white, () => state.toggleLight()),
          const SizedBox(width: 20),
          _buildActionButton(Icons.camera_alt, Colors.white, () => _takeSnapshot()),
          const SizedBox(width: 20),
          _buildActionButton(Icons.videocam, Colors.white, () {}),
          const SizedBox(width: 20),
          _buildActionButton(Icons.campaign, state.isHornOn ? Colors.red : Colors.white, () => state.toggleHorn(!state.isHornOn)),
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
