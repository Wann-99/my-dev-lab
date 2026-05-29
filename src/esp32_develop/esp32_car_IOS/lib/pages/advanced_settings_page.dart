import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  int _servoChannel = 0;
  double _servoAngle = 90.0;
  late TextEditingController _voltageController;

  @override
  void initState() {
    super.initState();
    _voltageController = TextEditingController();
  }

  @override
  void dispose() {
    _voltageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    if (_voltageController.text.isEmpty || double.tryParse(_voltageController.text) != state.voltageMultiplier) {
       _voltageController.text = state.voltageMultiplier.toStringAsFixed(2);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedSettings),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: '舵机校准 (Servo)',
              icon: Icons.settings_input_component_rounded,
              children: [
                const Text(
                  '调整下方滑块以测试舵机角度。校准完成后，系统将自动保存中位偏置。',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('选择通道', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    DropdownButton<int>(
                      value: _servoChannel,
                      items: List.generate(16, (i) => DropdownMenuItem(value: i, child: Text('通道 $i'))),
                      onChanged: (val) {
                        if (val != null) setState(() => _servoChannel = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('当前角度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('${_servoAngle.toInt()}°', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF29B6F6))),
                  ],
                ),
                Slider(
                  value: _servoAngle,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  activeColor: const Color(0xFF29B6F6),
                  onChanged: (val) {
                    setState(() => _servoAngle = val);
                    state.sendCommand(jsonEncode({
                      "cmd": "servo",
                      "channel": _servoChannel,
                      "angle": val.toInt()
                    }));
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickButton('0°', () => _setAngle(state, 0)),
                    const SizedBox(width: 12),
                    _buildQuickButton('90° (居中)', () => _setAngle(state, 90)),
                    const SizedBox(width: 12),
                    _buildQuickButton('180°', () => _setAngle(state, 180)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            _buildSection(
              title: '系统校准 (Calibration)',
              icon: Icons.compass_calibration_rounded,
              children: [
                const Text(
                  '电压校准：如果您发现 App 显示电压与万用表测量值不符，请输入实测电压，系统将自动计算校准系数。',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),
                
                // Method 1: Manual Multiplier
                Row(
                  children: [
                    const Expanded(
                      child: Text('校准系数', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixText: 'x',
                        ),
                        controller: _voltageController,
                        onSubmitted: (val) {
                          final multiplier = double.tryParse(val);
                          if (multiplier != null && multiplier > 0) {
                            state.setVoltageMultiplier(multiplier);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Method 2: Actual Voltage Input
                Row(
                  children: [
                    const Expanded(
                      child: Text('实测电压', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixText: 'V',
                        ),
                        onSubmitted: (val) {
                          final actual = double.tryParse(val);
                          if (actual != null && actual > 0) {
                            state.setVoltageByActual(actual);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('电压校准成功')));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildStatusRow('硬件原始电压', '${state.rawBatteryVoltage.toStringAsFixed(2)} V', const Color(0xFF64748B)),
                      const Divider(height: 16),
                      _buildStatusRow('App 显示电压', '${state.batteryVoltage.toStringAsFixed(2)} V', const Color(0xFF29B6F6)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAngle(CarState state, double angle) {
    setState(() => _servoAngle = angle);
    state.sendCommand(jsonEncode({
      "cmd": "servo",
      "channel": _servoChannel,
      "angle": angle.toInt()
    }));
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF29B6F6), size: 20),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF29B6F6),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label),
    );
  }
}
