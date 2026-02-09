import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

class DeviceSettingsPage extends StatefulWidget {
  const DeviceSettingsPage({super.key});

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  final _carIpController = TextEditingController();
  final _cameraIpController = TextEditingController();
  final _relayServerController = TextEditingController();
  bool _isRemoteMode = false;
  double _maxSpeed = 0.7;
  double _patrolSpeed = 0.4;
  String _sensitivity = "Medium";
  String _resolution = "1080P";
  String _nightMode = "Auto";
  String _aiDetection = "All";
  double _detectionSensitivity = 0.75;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _carIpController.text = state.carIp;
    _cameraIpController.text = state.cameraIp;
    _relayServerController.text = state.relayServer;
    _isRemoteMode = state.isRemoteMode;
    _maxSpeed = state.maxSpeed;
    _patrolSpeed = state.patrolSpeed;
    _sensitivity = state.sensitivity;
    _resolution = state.resolution;
    _nightMode = state.nightMode;
    _aiDetection = state.aiDetection;
    _detectionSensitivity = state.detectionSensitivity;
  }

  @override
  void dispose() {
    _carIpController.dispose();
    _cameraIpController.dispose();
    _relayServerController.dispose();
    super.dispose();
  }

  void _saveAllSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newCarIp: _carIpController.text,
      newCameraIp: _cameraIpController.text,
      newMaxSpeed: _maxSpeed,
      newPatrolSpeed: _patrolSpeed,
      newSensitivity: _sensitivity,
      newResolution: _resolution,
      newNightMode: _nightMode,
      newAiDetection: _aiDetection,
      newDetectionSensitivity: _detectionSensitivity,
      newRelayServer: _relayServerController.text,
      newIsRemoteMode: _isRemoteMode,
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.saved), backgroundColor: Colors.green),
      );
  }

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
                  if (!mounted) return;
                  // Update UI state
                  setState(() {
                    _carIpController.text = state.carIp;
                    _cameraIpController.text = state.cameraIp;
                    _maxSpeed = state.maxSpeed;
                    _patrolSpeed = state.patrolSpeed;
                    _sensitivity = state.sensitivity;
                    _resolution = state.resolution;
                    _nightMode = state.nightMode;
                    _aiDetection = state.aiDetection;
                    _detectionSensitivity = state.detectionSensitivity;
                  });
                  navigator.pop(); // Close confirmation dialog
                  
                  // Show prompt to inform user that reboot is needed
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

    // 1. Select file
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      
      // 2. Confirmation dialog
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
      appBar: AppBar(
        title: Text(l10n.deviceSettings),
        actions: [
          TextButton(
            onPressed: _saveAllSettings,
            child: Text(l10n.save, style: const TextStyle(color: Color(0xFF00F0FF))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(l10n.networkSettings, [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _carIpController,
                    decoration: InputDecoration(
                      labelText: l10n.carIpAddress,
                      hintText: "e.g. 192.168.4.1",
                      prefixIcon: const Icon(Icons.router, color: Color(0xFF00F0FF)),
                      suffixIcon: IconButton(
                        icon: state.isDiscovering 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)))
                          : const Icon(Icons.search, color: Color(0xFF00F0FF)),
                        onPressed: state.isDiscovering ? null : () => state.startDiscovery(),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (state.discoveredDevices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("${l10n.discoveredDevices}:", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.discoveredDevices.map((device) => ActionChip(
                        label: Text("${device['id']} (${device['ip']})"),
                        backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                        side: const BorderSide(color: Color(0xFF00F0FF)),
                        onPressed: () {
                          setState(() {
                            _carIpController.text = device['ip']!;
                            // Auto-fill ID
                            state.saveAllSettings(newDeviceId: device['id']);
                          });
                        },
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _cameraIpController,
                decoration: InputDecoration(
                  labelText: l10n.cameraIpAddress,
                  hintText: "e.g. 192.168.4.2",
                  prefixIcon: const Icon(Icons.camera_alt, color: Color(0xFF00F0FF)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(l10n.remoteControlSettings, [
            SwitchListTile(
              title: Text(l10n.remoteMode, style: const TextStyle(fontSize: 15, color: Colors.white)),
              value: _isRemoteMode,
              onChanged: (v) => setState(() => _isRemoteMode = v),
              activeColor: const Color(0xFF00F0FF),
            ),
            if (_isRemoteMode) ...[
              const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _relayServerController,
                  decoration: InputDecoration(
                    labelText: l10n.relayServerAddress,
                    hintText: "e.g. 1.2.3.4:8081",
                    prefixIcon: const Icon(Icons.cloud, color: Color(0xFF00F0FF)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          _buildSection(l10n.motionSettings, [
            _buildSliderRow(l10n.maxSpeed, _maxSpeed, (v) => setState(() => _maxSpeed = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildSliderRow(l10n.patrolSpeed, _patrolSpeed, (v) => setState(() => _patrolSpeed = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildChoiceRow(l10n.obstacleSensitivity, {"High": l10n.high, "Medium": l10n.medium, "Low": l10n.low}, _sensitivity, (v) => setState(() => _sensitivity = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildSettingRow(l10n.rechargeThreshold, l10n.batteryLow),
          ]),
          const SizedBox(height: 20),
          _buildSection(l10n.visionSettings, [
            _buildChoiceRow(l10n.videoResolution, {"1080P": "1080P", "720P": "720P", "480P": "480P"}, _resolution, (v) => setState(() => _resolution = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildChoiceRow(l10n.nightMode, {"Auto": l10n.auto, "On": l10n.on, "Off": l10n.off}, _nightMode, (v) => setState(() => _nightMode = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildChoiceRow(l10n.aiDetection, {"Person": l10n.person, "Pet": l10n.pet, "All": l10n.all}, _aiDetection, (v) => setState(() => _aiDetection = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildSliderRow(l10n.detectionSensitivity, _detectionSensitivity, (v) => setState(() => _detectionSensitivity = v)),
          ]),
          const SizedBox(height: 20),
          _buildSection(l10n.advancedSettings, [
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
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
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

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return ListTile(
      title: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 15))),
          Expanded(
            flex: 5,
            child: Slider(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00F0FF),
              inactiveColor: Colors.white10,
            ),
          ),
          SizedBox(width: 40, child: Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.grey, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildChoiceRow(String label, Map<String, String> choices, String current, ValueChanged<String> onSelected) {
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Wrap(
            spacing: 8,
            children: choices.entries.map((entry) {
              final isSelected = entry.key == current;
              return GestureDetector(
                onTap: () => onSelected(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00F0FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isSelected ? const Color(0xFF00F0FF) : Colors.white24),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
