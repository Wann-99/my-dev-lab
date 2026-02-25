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
          SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.factoryReset),
        content: Text(l10n.factoryResetConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
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
                      title: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(l10n.factoryResetTitle),
                        ],
                      ),
                      content: Text(l10n.factoryResetSuccess),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.gotIt),
                        ),
                      ],
                    ),
                  );
                });
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
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
          SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rebootDevice),
        content: Text(l10n.rebootConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              context.read<CarState>().rebootDevice();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.rebooting), backgroundColor: Colors.blue),
                );
            },
            child: Text(l10n.confirm),
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
          SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange),
        );
      return;
    }
    if (!state.hasFirmwareUpdate) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.latestVersion)),
        );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newFirmwareFound(state.latestFirmwareVersion)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateContent, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(state.firmwareUpdateLog),
            const SizedBox(height: 16),
            Text(l10n.updateNote, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.later)),
          TextButton(
            onPressed: () {
              state.startDeviceOTA();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.otaCommandSent), backgroundColor: Colors.blue),
                );
            },
            child: Text(l10n.downloadNow),
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
          SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange),
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
          title: Text(l10n.firmwareUpdateLocal),
          content: Text(l10n.localOtaConfirm(result.files.single.name, (file.lengthSync() / 1024 / 1024).toStringAsFixed(2))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                state.startLocalOTA(file);
                Navigator.pop(dialogContext);
                messenger
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.localOtaStarted), backgroundColor: Colors.blue),
                  );
              },
              child: Text(l10n.confirm),
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
      appBar: AppBar(title: Text(l10n.advancedSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  l10n.firmwareUpdateOnline, 
                  state.currentFirmwareVersion, 
                  isLink: true, 
                  onTap: _handleDeviceUpdate,
                  action: state.hasFirmwareUpdate ? _buildUpdateBadge() : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                _buildSettingRow(
                  l10n.firmwareUpdateLocal, 
                  state.isLocalServerRunning ? l10n.running : l10n.selectFile, 
                  isLink: true, 
                  onTap: _handleLocalOTA,
                  action: state.isLocalServerRunning 
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        onPressed: () => state.stopLocalServer(),
                      )
                    : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                _buildSettingRow(l10n.factoryReset, "", isLink: true, onTap: _handleFactoryReset),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                _buildSettingRow(l10n.rebootDevice, "", isLink: true, onTap: _handleReboot),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                _buildSettingRow(l10n.exportLogs, "", isLink: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "NEW",
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, {bool isLink = false, Widget? action, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: Colors.grey)),
          if (action != null) ...[const SizedBox(width: 8), action],
          if (isLink) const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
