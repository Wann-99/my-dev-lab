import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class ControlEntryPage extends StatefulWidget {
  const ControlEntryPage({super.key});

  @override
  State<ControlEntryPage> createState() => _ControlEntryPageState();
}

class _ControlEntryPageState extends State<ControlEntryPage> {
  bool _isLightOn = false;
  bool _isHornOn = false;
  
  // Servo angles (Center at 90)
  double _servoPan = 90.0;
  double _servoTilt = 90.0;
  Timer? _servoUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide status bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _servoUpdateTimer?.cancel();
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Restore status bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleServoJoy(CarState state, double x, double y) {
    // Deadzone check
    if (x.abs() < 0.1 && y.abs() < 0.1) {
      _servoUpdateTimer?.cancel();
      _servoUpdateTimer = null;
      return;
    }

    // Start timer for continuous smooth movement if not already running
    if (_servoUpdateTimer == null) {
      _servoUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          // Increment angles based on joystick displacement (sensitivity)
          _servoPan = (_servoPan + x * 3.0).clamp(0.0, 180.0);
          _servoTilt = (_servoTilt - y * 3.0).clamp(0.0, 180.0);
        });

        state.sendCommand(jsonEncode({
          "cmd": "servo",
          "channel": 0, // Pan
          "angle": _servoPan.toInt()
        }));
        state.sendCommand(jsonEncode({
          "cmd": "servo",
          "channel": 1, // Tilt
          "angle": _servoTilt.toInt()
        }));
      });
    }
  }

  void _toggleLight(CarState state) {
    setState(() => _isLightOn = !_isLightOn);
    state.sendCommand(jsonEncode({"cmd": "light", "val": _isLightOn ? 1 : 0}));
  }

  void _toggleHorn(CarState state) {
    setState(() => _isHornOn = !_isHornOn);
    state.sendCommand(jsonEncode({"cmd": "horn", "val": _isHornOn ? 1 : 0}));
    // Auto turn off horn after 500ms
    if (_isHornOn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isHornOn) {
          setState(() => _isHornOn = false);
          state.sendCommand(jsonEncode({"cmd": "horn", "val": 0}));
        }
      });
    }
  }

  Future<void> _handleExit() async {
    // Restore orientation first
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Restore status bars
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    // Video stream URL:
    // In local mode, use the car's IP. 
    // In remote mode, you might need to route this through the relay server (e.g. port 8081 via FRP)
    final String streamUrl = state.carIp.isNotEmpty 
        ? (state.isRemoteMode && state.relayUrl.isNotEmpty 
            ? "http://${state.relayUrl}:8081/stream" 
            : "http://${state.carIp}:81/stream")
        : "";

    return PopScope(
      canPop: false, // Handle pop manually to ensure smooth transition
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Background: Video Stream
            Center(
              child: state.isConnected && streamUrl.isNotEmpty
                  ? Mjpeg(
                      isLive: true,
                      stream: streamUrl,
                      error: (context, error, stack) => Center(
                        child: Text(l10n.videoError, style: const TextStyle(color: Colors.white70)),
                      ),
                      loading: (context) => const CircularProgressIndicator(),
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(l10n.pleaseConnect, style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
            ),
  
            // 2. Top Center: Status Pill Bar
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _handleExit,
                        child: Row(
                          children: const [
                            Icon(Icons.menu_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text("菜单", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Icon(
                            state.batteryPercentage > 20 ? Icons.battery_full_rounded : Icons.battery_alert_rounded, 
                            color: _getBatteryColor(state.batteryPercentage), 
                            size: 18
                          ),
                          const SizedBox(width: 6),
                          Text("电量: ${state.batteryPercentage}%", style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state.isConnected ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(state.isConnected ? "已连接" : "未连接", style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () {
                          // Quick toggle for Auto Mode
                          state.setAutoMode(!state.isAutoMode);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.isAutoMode ? '已切换至 AI 自动跟踪模式' : '已切换至手动控制模式'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(state.isAutoMode ? Icons.smart_toy_rounded : Icons.person_rounded, color: state.isAutoMode ? Colors.greenAccent : Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(state.isAutoMode ? "AI自动" : "手动控制", style: TextStyle(color: state.isAutoMode ? Colors.greenAccent : Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Left: Movement Joystick
            Positioned(
              bottom: 40,
              left: 60,
              child: Joystick(
                mode: JoystickMode.all,
                listener: (details) {
                  state.sendCommand(jsonEncode({
                    "cmd": "move",
                    "vx": -details.y,
                    "vy": 0.0,
                    "vw": details.x
                  }));
                },
                base: _buildJoystickBase("控制摇杆"),
                stick: _buildJoystickStick(),
              ),
            ),

            // 4. Right: Servo Joystick
            Positioned(
              bottom: 40,
              right: 60,
              child: Joystick(
                mode: JoystickMode.all,
                listener: (details) => _handleServoJoy(state, details.x, details.y),
                base: _buildJoystickBase("舵机摇杆"),
                stick: _buildJoystickStick(),
              ),
            ),

            // 5. Middle-Right: Action Buttons (Horn & Light)
            Positioned(
              bottom: 60,
              right: 240,
              child: Column(
                children: [
                  _buildRoundButton(
                    label: "喇叭",
                    icon: _isHornOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    isActive: _isHornOn,
                    onTap: () => _toggleHorn(state),
                  ),
                  const SizedBox(height: 24),
                  _buildRoundButton(
                    label: "灯光",
                    icon: _isLightOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                    isActive: _isLightOn,
                    onTap: () => _toggleLight(state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int pct) {
    if (pct > 60) return Colors.greenAccent;
    if (pct > 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildJoystickBase(String label) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildJoystickStick() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
