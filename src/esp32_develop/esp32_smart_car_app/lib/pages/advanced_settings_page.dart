import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  void _handleFactoryReset() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    if (!state.isConnected) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseConnectFirst), 
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.factoryReset, style: const TextStyle(color: Color(0xFF333333))),
        content: Text(l10n.factoryResetConfirm, style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF999999)))
          ),
          TextButton(
            onPressed: () {
              final state = context.read<CarState>();
              final navigator = Navigator.of(context);
                
                state.factoryReset().then((_) {
                  navigator.pop(); // Close confirmation dialog
                  
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orangeAccent),
                          const SizedBox(width: 12),
                          Text(l10n.factoryResetTitle, style: const TextStyle(color: Color(0xFF333333))),
                        ],
                      ),
                      content: Text(l10n.factoryResetSuccess, style: const TextStyle(color: Color(0xFF666666))),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.gotIt, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        ),
                      ],
                    ),
                  );
                });
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleReboot() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    if (!state.isConnected) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseConnectFirst), 
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.rebootDevice, style: const TextStyle(color: Color(0xFF333333))),
        content: Text(l10n.rebootConfirm, style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF999999)))
          ),
          TextButton(
            onPressed: () {
              context.read<CarState>().rebootDevice();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.rebooting), 
                    backgroundColor: Colors.blueAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            child: Text(l10n.confirm, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleDeviceUpdate() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    if (!state.isConnected) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseConnectFirst), 
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (!state.hasFirmwareUpdate) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.latestVersion), behavior: SnackBarBehavior.floating),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.newFirmwareFound(state.latestFirmwareVersion), style: const TextStyle(color: Color(0xFF333333))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateContent, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Text(state.firmwareUpdateLog, style: const TextStyle(color: Color(0xFF666666))),
            const SizedBox(height: 20),
            Text(l10n.updateNote, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(l10n.later, style: const TextStyle(color: Color(0xFF999999)))
          ),
          TextButton(
            onPressed: () {
              state.startDeviceOTA();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.otaCommandSent), 
                    backgroundColor: Colors.blueAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            child: Text(l10n.downloadNow, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLocalOTA() async {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    if (!state.isConnected) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseConnectFirst), 
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(l10n.firmwareUpdateLocal, style: const TextStyle(color: Color(0xFF333333))),
          content: Text(l10n.localOtaConfirm(result.files.single.name, (file.lengthSync() / 1024 / 1024).toStringAsFixed(2)), style: const TextStyle(color: Color(0xFF666666))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF999999)))
            ),
            TextButton(
              onPressed: () {
                state.startLocalOTA(file);
                Navigator.pop(dialogContext);
                messenger
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(l10n.localOtaStarted), 
                      backgroundColor: Colors.blueAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              child: Text(l10n.confirm, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.advancedSettings, 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF333333))
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            stretch: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection("Firmware Updates", [
                  _buildSettingRow(
                    "Main Controller", 
                    state.currentFirmwareVersion, 
                    onTap: _handleDeviceUpdate,
                    badge: state.hasFirmwareUpdate ? "NEW" : null,
                  ),
                  _buildSettingRow(
                    "Vision Controller", 
                    state.currentCamFirmwareVersion, 
                    onTap: () {},
                    badge: state.hasCamFirmwareUpdate ? "NEW" : null,
                  ),
                  _buildSettingRow(
                    l10n.firmwareUpdateLocal, 
                    state.isLocalServerRunning ? l10n.running : l10n.selectFile, 
                    onTap: _handleLocalOTA,
                    action: state.isLocalServerRunning 
                      ? IconButton(
                          icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                          onPressed: () => state.stopLocalServer(),
                        )
                      : null,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection("Device Control", [
                  _buildSettingRow(l10n.factoryReset, "", onTap: _handleFactoryReset, color: Colors.redAccent),
                  _buildSettingRow(l10n.rebootDevice, "", onTap: _handleReboot),
                  _buildSettingRow(l10n.exportLogs, ""),
                ]),
                const SizedBox(height: 24),
                _buildSection("Interface", [
                  _buildSwitchRow(
                    "Emergency Stop Button", 
                    "Show global stop button", 
                    state.showEmergencyStop, 
                    (v) => state.saveAllSettings(newShowEmergencyStop: v),
                  ),
                ]),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title, 
            style: const TextStyle(
              color: Color(0xFF999999), 
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, String value, {Widget? action, VoidCallback? onTap, String? badge, Color? color}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Row(
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF333333))
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) 
            Text(value, style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
          if (action != null) ...[const SizedBox(width: 8), action],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title, 
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333))
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
      ),
      activeThumbColor: Colors.white,
      activeTrackColor: primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
