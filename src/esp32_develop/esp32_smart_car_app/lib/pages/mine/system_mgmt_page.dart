import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/car_state.dart';

class SystemManagementPage extends StatelessWidget {
  const SystemManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<CarState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemManagement),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory(l10n.advancedSettings, [
            _buildActionTile(
              context,
              l10n.firmwareUpdateOnline,
              state.isConnected ? state.currentFirmwareVersion : "设备离线",
              Icons.system_update,
              onTap: () => _handleDeviceUpdate(context, state, l10n),
              trailing: state.hasFirmwareUpdate ? _buildUpdateBadge() : null,
              enabled: state.isConnected,
            ),
            _buildActionTile(
              context,
              l10n.firmwareUpdateLocal,
              state.isConnected 
                ? (state.isLocalServerRunning ? l10n.running : l10n.selectFile)
                : "设备离线",
              Icons.upload_file,
              onTap: () => _handleLocalOTA(context, state, l10n),
              trailing: state.isLocalServerRunning 
                ? IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    onPressed: () => state.stopLocalServer(),
                  )
                : null,
              enabled: state.isConnected,
            ),
          ]),
          const SizedBox(height: 20),
          _buildCategory("维护与偏好", [
            _buildActionTile(context, l10n.language, "", Icons.language, onTap: () => _showLanguageDialog(context, state, l10n)),
            _buildActionTile(
              context, 
              l10n.rebootDevice, 
              state.isConnected ? "" : "设备离线", 
              Icons.restart_alt, 
              onTap: () => _handleReboot(context, state, l10n),
              enabled: state.isConnected,
            ),
            _buildActionTile(
              context, 
              l10n.factoryReset, 
              state.isConnected ? "" : "设备离线", 
              Icons.restore, 
              onTap: () => _handleFactoryReset(context, state, l10n), 
              isDestructive: true,
              enabled: state.isConnected,
            ),
            _buildActionTile(context, l10n.exportLogs, "", Icons.history_edu, onTap: () {}),
          ]),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        Card(
          color: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    {VoidCallback? onTap, Widget? trailing, bool isDestructive = false, bool enabled = true}
  ) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : const Color(0xFF00F0FF), size: 22),
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 15)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
        onTap: enabled ? onTap : () {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange));
        },
      ),
    );
  }

  Widget _buildUpdateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
      child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // Reuse logic from DeviceSettingsPage
  void _handleDeviceUpdate(BuildContext context, CarState state, AppLocalizations l10n) async {
    if (!state.isConnected) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange));
      return;
    }
    await state.checkFirmwareUpdate();
    if (!context.mounted) return;
    if (state.hasFirmwareUpdate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.firmwareUpdateOnline),
          content: Text("${l10n.newFirmwareFound(state.latestFirmwareVersion)}\n${l10n.version(state.currentFirmwareVersion)}"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                state.startFirmwareUpdate();
                Navigator.pop(context);
              },
              child: Text(l10n.downloadNow),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.latestVersion)));
    }
  }

  void _handleLocalOTA(BuildContext context, CarState state, AppLocalizations l10n) async {
    if (state.isLocalServerRunning) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text("本地服务正在运行中")));
      return;
    }
    await state.startLocalOTAServer();
  }

  void _handleReboot(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rebootDevice),
        content: const Text("确定要重启设备吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(onPressed: () { state.reboot(); Navigator.pop(context); }, child: const Text("确定")),
        ],
      ),
    );
  }

  void _handleFactoryReset(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.factoryReset),
        content: const Text("确定要恢复出厂设置吗？此操作将清除所有配置并重启设备。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () { state.factoryReset(); Navigator.pop(context); }, 
            child: const Text("恢复", style: TextStyle(color: Colors.red))
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
              title: const Text("English"),
              trailing: state.locale.languageCode == 'en' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () { state.setLocale(const Locale('en')); Navigator.pop(context); },
            ),
            ListTile(
              title: const Text("中文"),
              trailing: state.locale.languageCode == 'zh' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () { state.setLocale(const Locale('zh')); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }
}
