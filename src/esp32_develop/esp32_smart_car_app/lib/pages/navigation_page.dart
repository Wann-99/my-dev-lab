import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceStatusCard(context, state),
          const SizedBox(height: 16),
          _buildBindingSection(context, state),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (state.isConnected ? Colors.green : const Color(0xFF00F0FF)).withValues(alpha: 0.2),
            Colors.transparent
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (state.isConnected ? Colors.green : const Color(0xFF00F0FF)).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.isConnected ? Icons.check_circle : Icons.error_outline,
                color: state.isConnected ? Colors.green : Colors.red,
                size: 40,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isConnected ? l10n.deviceOnline : l10n.deviceOffline,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      state.isConnected ? l10n.connectionNormal : l10n.pleaseConnect,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Car IP", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(state.carIp.isEmpty ? "--" : state.carIp,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Camera IP", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(state.cameraIp.isEmpty ? "--" : state.cameraIp,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (state.isConnected) {
                  state.disconnect();
                } else {
                  state.connect();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isConnected
                    ? Colors.red.withValues(alpha: 0.8)
                    : const Color(0xFF00F0FF).withValues(alpha: 0.8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(state.isConnected ? l10n.disconnectDevice : l10n.connectDevice),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBindingSection(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceBinding,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF)),
          ),
          const SizedBox(height: 10),
          if (state.isBound)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: Text(l10n.unbindDevice, style: const TextStyle(color: Colors.red)),
              subtitle: Text(l10n.unbindWarning, style: const TextStyle(fontSize: 12)),
              onTap: () => _showUnbindDialog(context, state, l10n),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_link, color: Colors.green),
              title: Text(l10n.bindNewDevice, style: const TextStyle(color: Colors.green)),
              subtitle: Text(l10n.bindDescription, style: const TextStyle(fontSize: 12)),
              onTap: () => _showBindDialog(context, state, l10n),
            ),
        ],
      ),
    );
  }

  void _showUnbindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmUnbind),
        content: Text(l10n.unbindConfirmationMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              state.unbindDevice();
              Navigator.pop(context);
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    state.startDiscovery();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.searchingDevices, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (state.isDiscovering)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(icon: const Icon(Icons.refresh), onPressed: () => state.startDiscovery()),
                ],
              ),
              const SizedBox(height: 20),
              Consumer<CarState>(
                builder: (context, state, child) {
                  if (state.discoveredDevices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(state.isDiscovering ? l10n.searching : l10n.noDevicesFound),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = state.discoveredDevices[index];
                      return ListTile(
                        leading: const Icon(Icons.directions_car, color: Color(0xFF00F0FF)),
                        title: Text(device['id'] ?? 'Unknown Device'),
                        subtitle: Text("IP: ${device['ip']}"),
                        onTap: () async {
                          await state.bindDevice(device['id']!, "Current User");
                          await state.saveAllSettings(newCarIp: device['ip'], newCameraIp: device['ip']);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.bindSuccess), backgroundColor: Colors.green),
                            );
                            state.connect();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
