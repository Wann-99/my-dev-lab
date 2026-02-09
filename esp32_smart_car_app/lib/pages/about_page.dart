import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutRoboCar),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // App Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "RoboCar-A",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            Text(
              l10n.version(state.currentAppVersion),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // Features Section
            _buildSectionTitle(l10n.features),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.wifi, l10n.realtimeControl, l10n.realtimeControlDesc),
            _buildFeatureItem(Icons.videocam, l10n.hdVideo, l10n.hdVideoDesc),
            _buildFeatureItem(Icons.explore, l10n.autoNav, l10n.autoNavDesc),
            _buildFeatureItem(Icons.psychology, l10n.aiVision, l10n.aiVisionDesc),
            
            const SizedBox(height: 40),
            
            // Check Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleCheckUpdate(context, state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.checkUpdate, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (state.hasAppUpdate) ...[
              const SizedBox(height: 12),
              Text(
                l10n.newVersionAvailable,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            
            const SizedBox(height: 60),
            Text(
              "© 2026 RoboCar-A. All Rights Reserved.",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF00F0FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00F0FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckUpdate(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state.hasAppUpdate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.newAppVersionFound(state.latestAppVersion)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateContent, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(state.appUpdateLog),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.later)),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.downloading), backgroundColor: Colors.blue),
                  );
              },
              child: Text(l10n.downloadNow),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.latestVersion)),
        );
    }
  }
}
