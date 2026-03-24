import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutRoboCar),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF29B6F6).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.directions_car_rounded, size: 80, color: Color(0xFF29B6F6)),
            ),
            const SizedBox(height: 24),
            const Text(
              'RoboCar-A',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 48),
            _buildFeatureTile(
              l10n.realtimeControl,
              l10n.realtimeControlDesc,
              Icons.bolt_rounded,
              Colors.orange,
            ),
            _buildFeatureTile(
              l10n.hdVideo,
              l10n.hdVideoDesc,
              Icons.videocam_rounded,
              Colors.blue,
            ),
            _buildFeatureTile(
              l10n.autoNav,
              l10n.autoNavDesc,
              Icons.explore_rounded,
              Colors.green,
            ),
            _buildFeatureTile(
              l10n.aiVision,
              l10n.aiVisionDesc,
              Icons.psychology_rounded,
              Colors.purple,
            ),
            const SizedBox(height: 48),
            const Text(
              '© 2026 Smart Lab. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
