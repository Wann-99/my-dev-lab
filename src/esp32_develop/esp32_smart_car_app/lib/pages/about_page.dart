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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.aboutRoboCar, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            backgroundColor: Colors.transparent,
            elevation: 0,
            stretch: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "RoboCar-A",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.version(state.currentAppVersion),
                        style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                _buildSectionTitle(l10n.features),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(context, Icons.wifi_rounded, l10n.realtimeControl, l10n.realtimeControlDesc),
                      _buildFeatureItem(context, Icons.videocam_rounded, l10n.hdVideo, l10n.hdVideoDesc),
                      _buildFeatureItem(context, Icons.explore_rounded, l10n.autoNav, l10n.autoNavDesc),
                      _buildFeatureItem(context, Icons.psychology_rounded, l10n.aiVision, l10n.aiVisionDesc, isLast: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleCheckUpdate(context, state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                    ),
                    child: Text(l10n.checkUpdate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                if (state.hasAppUpdate) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      l10n.newVersionAvailable,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                
                const SizedBox(height: 60),
                const Center(
                  child: Text(
                    "© 2026 RoboCar-A. All Rights Reserved.",
                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15, 
          fontWeight: FontWeight.bold, 
          color: Color(0xFF999999),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String desc, {bool isLast = false}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
                const SizedBox(height: 4),
                Text(
                  desc, 
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.5),
                ),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(l10n.newAppVersionFound(state.latestAppVersion), style: const TextStyle(color: Color(0xFF333333))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateContent, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const SizedBox(height: 8),
              Text(state.appUpdateLog, style: const TextStyle(color: Color(0xFF666666))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(l10n.later, style: const TextStyle(color: Color(0xFF999999)))
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(l10n.downloading), 
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              child: Text(l10n.downloadNow, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.latestVersion),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
