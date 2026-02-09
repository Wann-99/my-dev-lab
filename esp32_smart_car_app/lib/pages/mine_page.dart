import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_settings_page.dart';
import 'network_config_page.dart';
import 'about_page.dart';
import 'login_page.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mine), centerTitle: true),
      body: ListView(
        children: [
          _buildUserHeader(context),
          const Divider(),
          _buildMenuItem(context, Icons.settings, l10n.deviceSettings, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceSettingsPage()));
          }),
          _buildMenuItem(context, Icons.wifi, l10n.networkConfig, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkConfigPage()));
          }),
          _buildMenuItem(
            context, 
            Icons.info_outline, 
            l10n.aboutRoboCar, 
            () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage()));
            },
            badge: state.hasAppUpdate ? "NEW" : null,
          ),
          _buildMenuItem(context, Icons.language, l10n.language, () {
            _showLanguageDialog(context, state, l10n);
          }),
          _buildMenuItem(context, Icons.history, l10n.logs, () {}),
          _buildMenuItem(context, Icons.bar_chart, l10n.statistics, () {}),
          const Divider(),
          _buildMenuItem(context, Icons.exit_to_app, l10n.logout, () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          const CircleAvatar(radius: 40, backgroundColor: Color(0xFF00F0FF), child: Icon(Icons.person, size: 50, color: Colors.black)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.admin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Consumer<CarState>(
                builder: (context, state, child) {
                  String displayId = state.deviceId == "Unbound" ? l10n.unbound : state.deviceId;
                  return Text("${l10n.id}: $displayId", style: const TextStyle(color: Colors.grey));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.english),
              trailing: state.locale.languageCode == 'en' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () {
                state.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.chinese),
              trailing: state.locale.languageCode == 'zh' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () {
                state.setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color, String? badge}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF00F0FF)),
      title: Row(
        children: [
          Text(title, style: TextStyle(color: color)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
