import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

class DeviceConfigPage extends StatefulWidget {
  const DeviceConfigPage({super.key});

  @override
  State<DeviceConfigPage> createState() => _DeviceConfigPageState();
}

class _DeviceConfigPageState extends State<DeviceConfigPage> {
  double _maxSpeed = 0.7;
  double _patrolSpeed = 0.4;
  double _steeringSensitivity = 0.5;
  double _accelerationSmoothness = 0.5;
  String _sensitivity = "Medium";
  String _resolution = "1080P";
  String _nightMode = "Auto";
  String _aiDetection = "All";
  double _detectionSensitivity = 0.75;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _maxSpeed = state.maxSpeed;
    _patrolSpeed = state.patrolSpeed;
    _steeringSensitivity = state.steeringSensitivity;
    _accelerationSmoothness = state.accelerationSmoothness;
    _sensitivity = state.sensitivity;
    _resolution = state.resolution;
    _nightMode = state.nightMode;
    _aiDetection = state.aiDetection;
    _detectionSensitivity = state.detectionSensitivity;
  }

  void _saveSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newMaxSpeed: _maxSpeed,
      newPatrolSpeed: _patrolSpeed,
      newSteeringSensitivity: _steeringSensitivity,
      newAccelerationSmoothness: _accelerationSmoothness,
      newSensitivity: _sensitivity,
      newResolution: _resolution,
      newNightMode: _nightMode,
      newAiDetection: _aiDetection,
      newDetectionSensitivity: _detectionSensitivity,
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.saved), backgroundColor: Colors.green),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceSettings), // Or use a new key if available
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(l10n.save, style: const TextStyle(color: Color(0xFF00F0FF))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(l10n.motionSettings, [
            _buildSliderRow(l10n.maxSpeed, _maxSpeed, (v) => setState(() => _maxSpeed = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildSliderRow(l10n.steeringSensitivity, _steeringSensitivity, (v) => setState(() => _steeringSensitivity = v)),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            _buildSliderRow(l10n.accelSmoothness, _accelerationSmoothness, (v) => setState(() => _accelerationSmoothness = v)),
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

  Widget _buildSettingRow(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Text(value, style: const TextStyle(color: Colors.grey)),
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
