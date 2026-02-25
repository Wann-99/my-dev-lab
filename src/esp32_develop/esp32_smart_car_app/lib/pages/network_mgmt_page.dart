import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

import 'network_config_page.dart';

class NetworkMgmtPage extends StatefulWidget {
  const NetworkMgmtPage({super.key});

  @override
  State<NetworkMgmtPage> createState() => _NetworkMgmtPageState();
}

class _NetworkMgmtPageState extends State<NetworkMgmtPage> {
  final _carIpController = TextEditingController();
  final _cameraIpController = TextEditingController();
  final _relayServerController = TextEditingController();
  final _deviceIdController = TextEditingController();
  bool _isRemoteMode = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _carIpController.text = state.carIp;
    _cameraIpController.text = state.cameraIp;
    _relayServerController.text = state.relayServer;
    _deviceIdController.text = state.deviceId;
    _isRemoteMode = state.isRemoteMode;
  }

  @override
  void dispose() {
    _carIpController.dispose();
    _cameraIpController.dispose();
    _relayServerController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newCarIp: _carIpController.text,
      newCameraIp: _cameraIpController.text,
      newRelayServer: _relayServerController.text,
      newDeviceId: _deviceIdController.text,
      newIsRemoteMode: _isRemoteMode,
    );

    // If connected, sync relay config to car
    if (state.isConnected) {
      state.sendCommand({
        "cmd": "set_relay",
        "url": _relayServerController.text,
        "id": _deviceIdController.text,
      });
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.saved), backgroundColor: Colors.green),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkConfig),
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
          _buildSection(l10n.ipInfo, [
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
                            _deviceIdController.text = device['id']!;
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
          _buildSection(l10n.networkSettings, [
            ListTile(
              leading: const Icon(Icons.wifi_find, color: Color(0xFF00F0FF)),
              title: Text(l10n.networkConfig),
              subtitle: const Text("配置设备连接到指定 WiFi (SoftAP)"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkConfigPage()));
              },
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
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _deviceIdController,
                decoration: InputDecoration(
                  labelText: l10n.id,
                  hintText: "e.g. car_01",
                  prefixIcon: const Icon(Icons.fingerprint, color: Color(0xFF00F0FF)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
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
}
