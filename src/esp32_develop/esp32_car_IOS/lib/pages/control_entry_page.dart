import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

/// Fullscreen landscape MANUAL control page.
/// Navigated to from ControlPage → 手动 tab → 开始控制.
/// Contains ONLY joystick controls; no auto/AI mode switching.
class ControlEntryPage extends StatefulWidget {
  const ControlEntryPage({super.key});

  @override
  State<ControlEntryPage> createState() => _ControlEntryPageState();
}

class _ControlEntryPageState extends State<ControlEntryPage> {
  bool _isLightOn = false;
  bool _isHornOn  = false;

  // Servo: Pan 0–180°, Tilt 0–70° (hardware default 35°)
  double _servoPan  = 90.0;
  double _servoTilt = 35.0;
  Timer? _servoTimer;
  Timer? _distanceTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<CarState>();
      // Send initial servo positions to hardware
      state.sendCommand(jsonEncode({"cmd": "servo", "channel": 0, "angle": _servoPan.toInt()}));
      state.sendCommand(jsonEncode({"cmd": "servo", "channel": 1, "angle": _servoTilt.toInt()}));
      // Poll distance/status every 1 s
      _distanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state.sendCommand(jsonEncode({"cmd": "status"}));
      });
    });
  }

  @override
  void dispose() {
    _servoTimer?.cancel();
    _distanceTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Servo joystick ─────────────────────────────────────────────────────────

  void _handleServoJoy(CarState state, double x, double y) {
    if (x.abs() < 0.1 && y.abs() < 0.1) {
      _servoTimer?.cancel();
      _servoTimer = null;
      return;
    }
    _servoTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _servoPan  = (_servoPan  - x * 3.0).clamp(0.0, 180.0);
        _servoTilt = (_servoTilt - y * 3.0).clamp(0.0,  70.0);
      });
      state.sendCommand(jsonEncode({"cmd": "servo", "channel": 0, "angle": _servoPan.toInt()}));
      state.sendCommand(jsonEncode({"cmd": "servo", "channel": 1, "angle": _servoTilt.toInt()}));
    });
  }

  // ── Horn / Light ───────────────────────────────────────────────────────────

  void _toggleLight(CarState state) {
    setState(() => _isLightOn = !_isLightOn);
    state.sendCommand(jsonEncode({"cmd": "light", "val": _isLightOn ? 1 : 0}));
  }

  void _toggleHorn(CarState state) {
    setState(() => _isHornOn = !_isHornOn);
    state.sendCommand(jsonEncode({"cmd": "horn", "val": _isHornOn ? 1 : 0}));
    if (_isHornOn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isHornOn) {
          setState(() => _isHornOn = false);
          state.sendCommand(jsonEncode({"cmd": "horn", "val": 0}));
        }
      });
    }
  }

  // ── Exit ───────────────────────────────────────────────────────────────────

  Future<void> _exit() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n  = AppLocalizations.of(context)!;

    // Account for iPhone notch / Dynamic Island (horizontal safe area in landscape)
    final EdgeInsets safe = MediaQuery.of(context).padding;

    final String effectiveCamIp = state.camIp.isNotEmpty ? state.camIp : state.carIp;
    final String streamUrl = state.camStreamUrl.isNotEmpty
        ? state.camStreamUrl
        : (effectiveCamIp.isNotEmpty ? 'http://$effectiveCamIp:81/stream' : '');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 1. Background: raw camera stream ──────────────────────────
            Center(
              child: state.isConnected && streamUrl.isNotEmpty
                  ? Mjpeg(
                      isLive: true,
                      stream: streamUrl,
                      error: (context, _, __) => Center(
                        child: Text(l10n.videoError,
                            style: const TextStyle(color: Colors.white70)),
                      ),
                      loading: (_) => const CircularProgressIndicator(),
                    )
                  : Center(
                      child: Text(l10n.pleaseConnect,
                          style: const TextStyle(color: Colors.white70)),
                    ),
            ),

            // ── 2. Top status bar — respects notch / Dynamic Island ───────
            Positioned(
              top: safe.top + 8,
              left: 0,
              right: 0,
              child: Center(child: _buildStatusBar(state)),
            ),

            // ── 3. Left: movement joystick — respects home indicator ──────
            Positioned(
              bottom: safe.bottom + 24,
              left: safe.left + 40,
              child: Joystick(
                mode: JoystickMode.all,
                listener: (d) => state.sendCommand(jsonEncode({
                  "cmd": "move",
                  "vx": -d.y,
                  "vy": 0.0,
                  "vw": d.x,
                })),
                base: _joystickBase('控制摇杆'),
                stick: _joystickStick(),
              ),
            ),

            // ── 4. Middle: Horn & Light ───────────────────────────────────
            Positioned(
              bottom: safe.bottom + 44,
              right: safe.right + 220,
              child: Column(
                children: [
                  _iconBtn(
                    label: '喇叭',
                    icon: _isHornOn
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    active: _isHornOn,
                    onTap: () => _toggleHorn(state),
                  ),
                  const SizedBox(height: 24),
                  _iconBtn(
                    label: '灯光',
                    icon: _isLightOn
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    active: _isLightOn,
                    onTap: () => _toggleLight(state),
                  ),
                ],
              ),
            ),

            // ── 5. Right: servo joystick — respects home indicator ────────
            Positioned(
              bottom: safe.bottom + 24,
              right: safe.right + 40,
              child: Joystick(
                mode: JoystickMode.all,
                listener: (d) => _handleServoJoy(state, d.x, d.y),
                base: _joystickBase('舵机摇杆'),
                stick: _joystickStick(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status bar (back · battery · connection · distance) ───────────────────

  Widget _buildStatusBar(CarState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _exit,
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('返回',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _vDiv(),
          const SizedBox(width: 16),
          Icon(
            state.batteryPercentage > 20
                ? Icons.battery_full_rounded
                : Icons.battery_alert_rounded,
            color: _batteryColor(state.batteryPercentage),
            size: 16,
          ),
          const SizedBox(width: 4),
          Text('${state.batteryPercentage}%',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 14),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 6),
          Text(state.isConnected ? '已连接' : '未连接',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 14),
          Icon(
            Icons.radar_rounded,
            size: 16,
            color: state.radarDistance > 0 && state.radarDistance < 30
                ? Colors.redAccent
                : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            state.radarDistance > 0
                ? '${state.radarDistance.toStringAsFixed(1)} cm'
                : '-- cm',
            style: TextStyle(
              fontSize: 13,
              color: state.radarDistance > 0 && state.radarDistance < 30
                  ? Colors.redAccent
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _vDiv() => Container(
      width: 1, height: 16, color: Colors.white.withOpacity(0.25));

  Color _batteryColor(int pct) {
    if (pct > 60) return Colors.greenAccent;
    if (pct > 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _joystickBase(String label) => Container(
        width: 160, height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _joystickStick() => Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.30),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
          ],
        ),
      );

  Widget _iconBtn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.40)
                  : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.30), width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
