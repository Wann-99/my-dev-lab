import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';
import 'control_entry_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool _isManualMode = true;

  // Switch tabs and activate / deactivate the corresponding mode on the car.
  void _switchMode(bool toManual, CarState state) {
    setState(() => _isManualMode = toManual);
    if (toManual) {
      // Deactivate any auto mode
      if (state.isAutoMode) state.setAutoMode(false);
    } else {
      // Activate AI tracking:
      //   remote mode → Python ai_driver.py (MQTT + video stream on port 5001)
      //   local mode  → car firmware obstacle avoidance
      state.setAutoMode(true, remoteOverride: state.isRemoteMode ? true : false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n  = AppLocalizations.of(context)!;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '控制台',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 32),

            // ── Mode selector ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: l10n.manual,
                    icon: Icons.sports_esports_rounded,
                    isActive: _isManualMode,
                    onTap: () => _switchMode(true, context.read<CarState>()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _modeButton(
                    label: 'AI 跟踪',
                    icon: Icons.psychology_rounded,
                    isActive: !_isManualMode,
                    onTap: () => _switchMode(false, context.read<CarState>()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Content area ───────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _isManualMode
                      ? _buildManualContent(l10n, state)
                      : _buildAiContent(state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manual content: icon + "开始控制" button ───────────────────────────────

  Widget _buildManualContent(AppLocalizations l10n, CarState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.gamepad_rounded, size: 80, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 24),
        const Text(
          '手动控制模式',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          '点击下方按钮进入全屏操控界面',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            if (state.isConnected) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ControlEntryPage()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.pleaseConnectFirst)),
              );
            }
          },
          icon: const Icon(Icons.play_arrow_rounded, size: 22),
          label: const Text('开始控制',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF29B6F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }

  // ── AI tracking content ────────────────────────────────────────────────────

  Widget _buildAiContent(CarState state) {
    // Remote auto: show Python ai_driver.py MJPEG stream (带识别框)
    if (state.isRemoteMode) {
      return _buildRemoteAiContent(state);
    }
    // Local auto: show obstacle avoidance status card
    return _buildLocalAiContent(state);
  }

  // Remote AI: MJPEG stream filling the content box
  Widget _buildRemoteAiContent(CarState state) {
    final String aiUrl = state.aiStreamUrl;
    if (!state.isConnected || aiUrl.isEmpty) {
      return _placeholder(
        icon: Icons.wifi_off_rounded,
        title: state.isConnected ? '请先设置 MQTT 服务器地址' : '未连接小车',
        subtitle: '远程 AI 跟踪需要连接后才能使用',
      );
    }
    return Stack(
      children: [
        // Video stream fills the box
        Positioned.fill(
          child: Mjpeg(
            isLive: true,
            stream: aiUrl,
            error: (context, err, _) => _placeholder(
              icon: Icons.videocam_off_rounded,
              title: 'AI 视频流连接失败',
              subtitle: '请确认服务器 ai_driver.py 已启动（端口 5001）',
              dark: true,
            ),
            loading: (_) => Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.greenAccent),
                    SizedBox(height: 12),
                    Text('正在连接 AI 视频流...',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Status badge at bottom
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 7),
                  const Text('远程 AI 跟踪运行中',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Local AI: obstacle avoidance status card
  Widget _buildLocalAiContent(CarState state) {
    final bool active = state.isConnected && state.isAutoMode;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.orange.withOpacity(0.12)
                : const Color(0xFFF1F5F9),
          ),
          child: Icon(Icons.sensors_rounded,
              size: 44,
              color: active ? Colors.orange : const Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 20),
        Text(
          active ? '避障模式开启' : (state.isConnected ? '正在激活...' : '未连接小车'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: active ? Colors.orange.shade700 : const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          active ? '小车正在自主避开障碍物' : '请先连接小车',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        const SizedBox(height: 32),
        const Text(
          '切回"手动"标签页将关闭避障模式',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
        ),
      ],
    );
  }

  // ── Shared placeholder ─────────────────────────────────────────────────────

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String subtitle,
    bool dark = false,
  }) {
    return Container(
      color: dark ? Colors.black : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 56,
              color: dark ? Colors.white24 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white54 : const Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white30 : const Color(0xFFCBD5E1))),
          ),
        ],
      ),
    );
  }

  // ── Mode button ────────────────────────────────────────────────────────────

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF29B6F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isActive
                  ? const Color(0xFF29B6F6)
                  : const Color(0xFFE2E8F0)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF29B6F6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isActive ? Colors.white : const Color(0xFF64748B),
                size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
