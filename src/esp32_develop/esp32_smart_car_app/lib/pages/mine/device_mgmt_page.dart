import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/car_state.dart';

class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  double _maxSpeed = 0.5;
  double _patrolSpeed = 0.3;
  String _sensitivity = "Medium";
  String _resolution = "720P";
  String _nightMode = "Auto";
  String _aiDetection = "All";
  double _detectionSensitivity = 0.5;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _maxSpeed = state.maxSpeed;
    _patrolSpeed = state.patrolSpeed;
    _sensitivity = state.obstacleSensitivity;
    _resolution = state.videoResolution;
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
      newObstacleSensitivity: _sensitivity,
      newVideoResolution: _resolution,
      newNightMode: _nightMode,
      newAiDetection: _aiDetection,
      newDetectionSensitivity: _detectionSensitivity,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.saved), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceManagement),
        actions: [
          IconButton(onPressed: _saveSettings, icon: const Icon(Icons.check)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory(l10n.motionSettings, [
            _buildSliderRow(l10n.maxSpeed, _maxSpeed, (v) => setState(() => _maxSpeed = v)),
            _buildSliderRow(l10n.patrolSpeed, _patrolSpeed, (v) => setState(() => _patrolSpeed = v)),
            _buildChoiceRow(l10n.obstacleSensitivity, {"High": l10n.high, "Medium": l10n.medium, "Low": l10n.low}, _sensitivity, (v) => setState(() => _sensitivity = v)),
          ]),
          const SizedBox(height: 20),
          _buildCategory(l10n.visionSettings, [
            _buildChoiceRow(l10n.videoResolution, {"1080P": "1080P", "720P": "720P", "480P": "480P"}, _resolution, (v) => setState(() => _resolution = v)),
            _buildChoiceRow(l10n.nightMode, {"Auto": l10n.auto, "On": l10n.on, "Off": l10n.off}, _nightMode, (v) => setState(() => _nightMode = v)),
            _buildChoiceRow(l10n.aiDetection, {"Person": l10n.person, "Pet": l10n.pet, "All": l10n.all}, _aiDetection, (v) => setState(() => _aiDetection = v)),
            _buildSliderRow(l10n.detectionSensitivity, _detectionSensitivity, (v) => setState(() => _detectionSensitivity = v)),
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

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Slider(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00F0FF),
        inactiveColor: Colors.white10,
      ),
      trailing: Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildChoiceRow(String label, Map<String, String> choices, String current, ValueChanged<String> onSelected) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Wrap(
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
                style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontSize: 11),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
