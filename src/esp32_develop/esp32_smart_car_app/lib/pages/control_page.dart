import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '控制台',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 32),
            
            // Mode Selector
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    l10n.manual,
                    Icons.sports_esports_rounded,
                    _isManualMode,
                    () => setState(() => _isManualMode = true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeButton(
                    'AI 跟踪',
                    Icons.psychology_rounded,
                    !_isManualMode,
                    () => setState(() => _isManualMode = false),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Mode Details
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
                child: _isManualMode ? _buildManualView(l10n, state) : _buildAIView(l10n, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF29B6F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? const Color(0xFF29B6F6) : const Color(0xFFE2E8F0)),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFF29B6F6).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : const Color(0xFF64748B), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualView(AppLocalizations l10n, CarState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.gamepad_rounded, size: 80, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 24),
        const Text(
          '手动控制模式',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          '点击下方按钮进入全屏操控界面',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF29B6F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('开始控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAIView(AppLocalizations l10n, CarState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.radar_rounded, size: 80, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 24),
        const Text(
          'AI 跟踪模式',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          '系统将自动锁定并跟踪目标',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Color(0xFF29B6F6)),
      ],
    );
  }
}
