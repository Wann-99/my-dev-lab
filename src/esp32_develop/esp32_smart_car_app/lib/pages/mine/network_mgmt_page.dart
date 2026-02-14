import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/car_state.dart';

class NetworkManagementPage extends StatefulWidget {
  const NetworkManagementPage({super.key});

  @override
  State<NetworkManagementPage> createState() => _NetworkManagementPageState();
}

class _NetworkManagementPageState extends State<NetworkManagementPage> {
  final _carIpController = TextEditingController();
  final _cameraIpController = TextEditingController();
  final _relayServerController = TextEditingController();
  bool _isRemoteMode = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _carIpController.text = state.carIp;
    _cameraIpController.text = state.cameraIp;
    _relayServerController.text = state.relayServer;
    _isRemoteMode = state.isRemoteMode;
  }

  @override
  void dispose() {
    _carIpController.dispose();
    _cameraIpController.dispose();
    _relayServerController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newCarIp: _carIpController.text,
      newCameraIp: _cameraIpController.text,
      newRelayServer: _relayServerController.text,
      newIsRemoteMode: _isRemoteMode,
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
    final state = context.watch<CarState>();
    final isConnected = state.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkManagement),
        actions: [
          IconButton(onPressed: _saveSettings, icon: const Icon(Icons.check)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory(l10n.networkSettings, [
            _buildTextField(l10n.carIpAddress, _carIpController, Icons.link),
            _buildTextField(l10n.cameraIpAddress, _cameraIpController, Icons.camera_alt),
          ]),
          const SizedBox(height: 20),
          _buildCategory("WiFi 连接", [
            Opacity(
              opacity: isConnected ? 1.0 : 0.5,
              child: ListTile(
                leading: const Icon(Icons.wifi_find, color: Color(0xFF00F0FF)),
                title: const Text("配置新 WiFi"),
                subtitle: Text(isConnected ? "让设备连接到其它路由器" : "设备离线，无法配置"),
                trailing: const Icon(Icons.chevron_right),
                onTap: isConnected ? () => _handleSeamlessWifiConfig(context) : () => _showOfflineWarning(context),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _buildCategory(l10n.remoteControlSettings, [
            Opacity(
              opacity: isConnected ? 1.0 : 0.5,
              child: SwitchListTile(
                title: Text(l10n.remoteMode),
                subtitle: isConnected ? null : const Text("设备离线，无法切换模式", style: TextStyle(color: Colors.orange, fontSize: 11)),
                secondary: const Icon(Icons.cloud_outlined, color: Color(0xFF00F0FF)),
                value: _isRemoteMode,
                onChanged: isConnected ? (v) => setState(() => _isRemoteMode = v) : (v) => _showOfflineWarning(context),
                activeThumbColor: const Color(0xFF00F0FF),
              ),
            ),
            if (_isRemoteMode)
              _buildTextField(l10n.relayServerAddress, _relayServerController, Icons.dns),
          ]),
        ],
      ),
    );
  }

  void _showOfflineWarning(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.pleaseConnectFirst), backgroundColor: Colors.orange),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF00F0FF), size: 20),
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }

  // Reuse WiFi config logic from DeviceSettingsPage
  void _handleSeamlessWifiConfig(BuildContext context) {
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
    state.scanWifi();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final carState = context.watch<CarState>();
          return AlertDialog(
            title: const Text("选择 WiFi"),
            content: SizedBox(
              width: double.maxFinite,
              child: carState.isScanning 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: carState.scanResults.length,
                    itemBuilder: (context, index) {
                      final net = carState.scanResults[index];
                      return ListTile(
                        title: Text(net['ssid'] ?? 'Unknown'),
                        onTap: () => _showPasswordDialog(context, net['ssid'] ?? ''),
                      );
                    },
                  ),
            ),
          );
        },
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, String ssid) {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("连接到 $ssid"),
        content: TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: "密码")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(
            onPressed: () {
              context.read<CarState>().configureWifi(ssid, passController.text);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(content: Text("配置已发送，设备重启中...")));
            }, 
            child: const Text("连接")
          ),
        ],
      ),
    );
  }
}
