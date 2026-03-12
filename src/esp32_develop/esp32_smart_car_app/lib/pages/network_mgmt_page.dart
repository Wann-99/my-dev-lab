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
  final _deviceIdController = TextEditingController();
  final _relayServerController = TextEditingController();
  bool _isRemoteMode = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarState>();
    _carIpController.text = state.carIp;
    _cameraIpController.text = state.cameraIp;
    _deviceIdController.text = state.deviceId;
    _relayServerController.text = state.relayServer;
    _isRemoteMode = state.isRemoteMode;
  }

  void _saveSettings() {
    final state = context.read<CarState>();
    final l10n = AppLocalizations.of(context)!;
    state.saveAllSettings(
      newCarIp: _carIpController.text,
      newCameraIp: _cameraIpController.text,
      newDeviceId: _deviceIdController.text,
      newRelayServer: _relayServerController.text,
      newIsRemoteMode: _isRemoteMode,
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
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.networkConfig, 
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
                _buildSection(l10n.ipInfo, [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _carIpController,
                          label: l10n.carIpAddress,
                          hint: "e.g. 192.168.4.1",
                          icon: Icons.router_rounded,
                          suffix: IconButton(
                            icon: state.isDiscovering 
                              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                              : Icon(Icons.search_rounded, color: primaryColor, size: 20),
                            onPressed: state.isDiscovering ? null : () => state.startDiscovery(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cameraIpController,
                          label: l10n.cameraIpAddress,
                          hint: "e.g. 192.168.4.2",
                          icon: Icons.camera_alt_rounded,
                        ),
                        if (state.discoveredDevices.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "${l10n.discoveredDevices}:", 
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.bold)
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: state.discoveredDevices.map((device) => ActionChip(
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  "${device['id']} (${device['ip']})", 
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                              side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _carIpController.text = device['ip']!;
                                  _deviceIdController.text = device['id']!;
                                });
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection(l10n.networkSettings, [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.wifi_find_rounded, color: primaryColor, size: 22),
                    ),
                    title: Text(l10n.networkConfig, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 22),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkConfigPage()));
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection(l10n.remoteControlSettings, [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(
                      l10n.remoteMode, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))
                    ),
                    value: _isRemoteMode,
                    onChanged: (v) => setState(() => _isRemoteMode = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: primaryColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _deviceIdController,
                          label: l10n.id,
                          hint: "e.g. car_01",
                          icon: Icons.fingerprint_rounded,
                        ),
                        if (_isRemoteMode) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _relayServerController,
                            label: l10n.relayServerAddress,
                            hint: "e.g. 1.2.3.4:8081",
                            icon: Icons.cloud_rounded,
                          ),
                        ],
                      ],
                    ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF333333), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        suffixIcon: suffix,
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
}
