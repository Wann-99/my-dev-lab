import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import '../utils/ui_utils.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF64B5F6), // Blue 400
              Color(0xFFBBDEFB), // Blue 100
              Color(0xFFF5F6FA), // Light Gray
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: Text(
                  l10n.device, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5, 
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  )
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                stretch: true,
                pinned: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Increased bottom padding to ensure scroll
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildDeviceStatusCard(context, state, l10n),
                    const SizedBox(height: 24),
                    _buildBindingSection(context, state, l10n),
                    const SizedBox(height: 40),
                    // Add some dummy content or large spacer to ensure scrollability
                    const SizedBox(height: 400), 
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(BuildContext context, CarState state, AppLocalizations l10n) {
    final isConnected = state.isConnected;
    final primaryColor = const Color(0xFF29B6F6);
    final color = isConnected ? const Color(0xFF66BB6A) : primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85), // Glass
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isConnected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? l10n.deviceOnline : l10n.deviceOffline,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected ? l10n.connectionNormal : l10n.pleaseConnect,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildIpInfo(context, l10n.carIpAddress, state.carIp.isEmpty ? "--" : state.carIp),
              const SizedBox(width: 16),
              _buildIpInfo(context, l10n.cameraIpAddress, state.cameraIp.isEmpty ? "--" : state.cameraIp),
            ],
          ),
          const SizedBox(height: 24),
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
                backgroundColor: isConnected ? const Color(0xFFFFEBEE) : primaryColor.withValues(alpha: 0.1),
                foregroundColor: isConnected ? Colors.redAccent : primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                state.isConnected ? l10n.disconnectDevice : l10n.connectDevice,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpInfo(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333)))),
          ],
        ),
      ),
    );
  }

  Widget _buildBindingSection(BuildContext context, CarState state, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            l10n.deviceBinding, 
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9), 
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            )
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85), // Glass
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: state.isBound
            ? _buildActionTile(
                context, 
                Icons.link_off_rounded, 
                l10n.unbindDevice, 
                l10n.unbindWarning, 
                Colors.redAccent, 
                () => _showUnbindDialog(context, state, l10n)
              )
            : _buildActionTile(
                context, 
                Icons.add_link_rounded, 
                l10n.bindNewDevice, 
                l10n.bindDescription, 
                const Color(0xFF66BB6A), 
                () => _showBindDialog(context, state, l10n)
              ),
        ),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title, 
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle, 
          style: const TextStyle(color: Color(0xFF999999), fontSize: 12, height: 1.4)
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  void _showUnbindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.confirmUnbind, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
        content: Text(l10n.unbindConfirmationMsg, style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF999999)))
          ),
          TextButton(
            onPressed: () {
              state.unbindDevice();
              Navigator.pop(context);
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBindDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    state.startDiscovery();
    UIUtils.showAppBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.searchingDevices, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))
                  ),
                  if (state.isDiscovering)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF29B6F6)))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF29B6F6)), 
                      onPressed: () => state.startDiscovery()
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: Consumer<CarState>(
                  builder: (context, state, child) {
                    if (state.discoveredDevices.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFE0E0E0)),
                            const SizedBox(height: 16),
                            Text(
                              state.isDiscovering ? l10n.searching : l10n.noDevicesFound,
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.discoveredDevices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = state.discoveredDevices[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_car_rounded, color: Color(0xFF29B6F6)),
                            ),
                            title: Text(
                              device['id'] ?? 'Unknown Device', 
                              style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)
                            ),
                            subtitle: Text(
                              "IP: ${device['ip']}", 
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 13)
                            ),
                            onTap: () async {
                              await state.bindDevice(device['id']!, "Current User");
                              await state.saveAllSettings(newCarIp: device['ip'], newCameraIp: device['ip']);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.bindSuccess), 
                                    backgroundColor: const Color(0xFF66BB6A),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                state.connect();
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
