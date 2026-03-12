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
  String _sensitivity = "Medium";
  String _resolution = "1080P";
  String _nightMode = "Auto";
  String _aiDetection = "All";
  double _detectionSensitivity = 0.75;
  double _voltageCalibration = 1.0;
  bool _useVoltageDivider = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _maxSpeed = state.maxSpeed;
    _patrolSpeed = state.patrolSpeed;
    _sensitivity = state.sensitivity;
    _resolution = state.resolution;
    _nightMode = state.nightMode;
    _aiDetection = state.aiDetection;
    _detectionSensitivity = state.detectionSensitivity;
    _voltageCalibration = state.voltageCalibration;
    _useVoltageDivider = state.useVoltageDivider;
  }

  void _saveSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newMaxSpeed: _maxSpeed,
      newPatrolSpeed: _patrolSpeed,
      newSensitivity: _sensitivity,
      newResolution: _resolution,
      newNightMode: _nightMode,
      newAiDetection: _aiDetection,
      newDetectionSensitivity: _detectionSensitivity,
      newVoltageCalibration: _voltageCalibration,
      newUseVoltageDivider: _useVoltageDivider,
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.saved), 
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.deviceSettings, 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF333333))
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    foregroundColor: primaryColor,
                  ),
                ),
              ),
            ],
            backgroundColor: Colors.transparent,
            elevation: 0,
            stretch: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection(l10n.motionSettings, [
                  _buildSliderRow(l10n.maxSpeed, _maxSpeed, (v) => setState(() => _maxSpeed = v)),
                  _buildSliderRow(l10n.patrolSpeed, _patrolSpeed, (v) => setState(() => _patrolSpeed = v)),
                  _buildChoiceRow(
                    l10n.obstacleSensitivity, 
                    {"High": l10n.high, "Medium": l10n.medium, "Low": l10n.low}, 
                    _sensitivity, 
                    (v) => setState(() => _sensitivity = v)
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection(l10n.visionSettings, [
                  _buildChoiceRow(l10n.videoResolution, {"1080P": "1080P", "720P": "720P", "480P": "480P"}, _resolution, (v) => setState(() => _resolution = v)),
                  _buildChoiceRow(l10n.nightMode, {"Auto": l10n.auto, "On": l10n.on, "Off": l10n.off}, _nightMode, (v) => setState(() => _nightMode = v)),
                  _buildChoiceRow(l10n.aiDetection, {"Person": l10n.person, "Pet": l10n.pet, "All": l10n.all}, _aiDetection, (v) => setState(() => _aiDetection = v)),
                  _buildSliderRow(l10n.detectionSensitivity, _detectionSensitivity, (v) => setState(() => _detectionSensitivity = v)),
                ]),
                const SizedBox(height: 24),
                _buildSection("Voltage Calibration", [
                  SwitchListTile(
                    title: const Text("Use R1/R2 Divider (x3.2)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text("Enable if device sends raw ADC voltage (e.g. 2.6V)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _useVoltageDivider,
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) => setState(() => _useVoltageDivider = v),
                  ),
                  const Divider(height: 1),
                  _buildSliderRow(
                    "Calibration", 
                    (_voltageCalibration - 0.5) / 1.0, // Normalize 0.5-1.5 to 0.0-1.0
                    (v) => setState(() => _voltageCalibration = 0.5 + (v * 1.0))
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

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        label, 
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333))
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: primaryColor,
            inactiveTrackColor: const Color(0xFFE0E0E0),
            thumbColor: Colors.white,
            overlayColor: primaryColor.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label.contains("Calibration") 
            ? "x${(0.5 + value).toStringAsFixed(2)}" 
            : "${(value * 100).toInt()}%", 
          style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  Widget _buildChoiceRow(String label, Map<String, String> choices, String current, ValueChanged<String> onSelected) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Text(
        label, 
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333))
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: choices.entries.map((entry) {
            final isSelected = entry.key == current;
            return ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (val) {
                if (val) onSelected(entry.key);
              },
              backgroundColor: const Color(0xFFF5F5F5),
              selectedColor: primaryColor.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? primaryColor : const Color(0xFF666666),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? primaryColor.withValues(alpha: 0.5) : Colors.transparent,
                  width: 1,
                ),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ),
    );
  }
}
