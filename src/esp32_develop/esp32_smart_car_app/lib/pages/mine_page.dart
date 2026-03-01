import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_config_page.dart';
import 'network_mgmt_page.dart';
import 'more_settings_page.dart';
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
          _buildUserHeader(context, state),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l10n.deviceSettings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _buildMenuItem(context, Icons.settings_input_component, l10n.deviceSettings, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceConfigPage()));
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l10n.networkConfig, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _buildMenuItem(context, Icons.wifi_tethering, l10n.networkConfig, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkMgmtPage()));
          }),
          const Divider(),
          _buildMenuItem(
            context,
            Icons.tune,
            "更多设置",
            () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoreSettingsPage()));
            },
          ),
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

  Widget _buildUserHeader(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 40, 
            backgroundColor: Color(0xFF00F0FF), 
            child: Icon(Icons.person, size: 50, color: Colors.black)
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.admin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                  state.isBound ? "${l10n.boundDevice}: ${state.deviceId}" : l10n.unbound,
                  style: TextStyle(color: state.isBound ? Colors.green : Colors.grey),
                ),
              ],
            ),
          ),
        ],
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
