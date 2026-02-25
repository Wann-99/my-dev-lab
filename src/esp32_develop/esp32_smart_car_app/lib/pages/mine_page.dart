import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_config_page.dart';
import 'network_mgmt_page.dart';
import 'advanced_settings_page.dart';
import 'about_page.dart';
import 'login_page.dart';
import 'network_config_page.dart'; // This is for SoftAP WiFi config

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
          _buildMenuItem(context, Icons.settings_input_component, l10n.deviceSettings, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceConfigPage()));
          }),
          _buildMenuItem(context, Icons.wifi_tethering, l10n.networkConfig, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkMgmtPage()));
          }),
          _buildMenuItem(context, Icons.admin_panel_settings, l10n.advancedSettings, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvancedSettingsPage()));
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
          const Divider(),
          _buildBindingSection(context, state),
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

  Widget _buildBindingSection(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deviceBinding, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF))),
          const SizedBox(height: 10),
          if (state.isBound)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: Text(l10n.unbindDevice, style: const TextStyle(color: Colors.red)),
              subtitle: Text(l10n.unbindWarning, style: const TextStyle(fontSize: 12)),
              onTap: () => _showUnbindDialog(context, state, l10n),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_link, color: Colors.green),
              title: Text(l10n.bindNewDevice, style: const TextStyle(color: Colors.green)),
              subtitle: Text(l10n.bindDescription, style: const TextStyle(fontSize: 12)),
              onTap: () => _showBindDialog(context, state, l10n),
            ),
        ],
      ),
    );
  }

  void _showUnbindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmUnbind),
        content: Text(l10n.unbindConfirmationMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              state.unbindDevice();
              Navigator.pop(context);
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    state.startDiscovery();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.searchingDevices, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (state.isDiscovering)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(icon: const Icon(Icons.refresh), onPressed: () => state.startDiscovery()),
                ],
              ),
              const SizedBox(height: 20),
              Consumer<CarState>(
                builder: (context, state, child) {
                  if (state.discoveredDevices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(state.isDiscovering ? l10n.searching : l10n.noDevicesFound),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = state.discoveredDevices[index];
                      return ListTile(
                        leading: const Icon(Icons.directions_car, color: Color(0xFF00F0FF)),
                        title: Text(device['id'] ?? 'Unknown Device'),
                        subtitle: Text("IP: ${device['ip']}"),
                        onTap: () async {
                          await state.bindDevice(device['id']!, "Current User");
                          // Also save the IP for connection
                          await state.saveAllSettings(newCarIp: device['ip'], newCameraIp: device['ip']);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.bindSuccess), backgroundColor: Colors.green),
                            );
                            // Auto connect after binding
                            state.connect();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
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
