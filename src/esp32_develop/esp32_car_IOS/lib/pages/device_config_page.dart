import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class DeviceConfigPage extends StatefulWidget {
  const DeviceConfigPage({super.key});

  @override
  State<DeviceConfigPage> createState() => _DeviceConfigPageState();
}

class _DeviceConfigPageState extends State<DeviceConfigPage> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    if (state.activeDevice != null) {
      _nameController.text = state.activeDevice!.name;
      _ipController.text = state.activeDevice!.ip;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备配置'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _nameController,
              label: '设备名称',
              hint: '例如: Robot Car_1',
              icon: Icons.edit_rounded,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _ipController,
              label: '设备 IP 地址',
              hint: '192.168.x.x',
              icon: Icons.lan_rounded,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (state.activeDevice != null) {
                    state.renameDevice(state.activeDevice!.id, _nameController.text);
                    // Update IP logic would be here if needed
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存')));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF29B6F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('保存配置', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF29B6F6), size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }
}
