import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(context, state),
            const SizedBox(height: 20),
            _buildInfoGrid(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, CarState state) {
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
        border: Border.all(color: (state.isConnected ? Colors.green : const Color(0xFF00F0FF)).withValues(alpha: 0.3)),
      ),
      child: Column(
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (state.isConnected) {
                  state.disconnect();
                } else {
                  state.connect().then((success) {
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.connectionFailed)),
                        );
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isConnected ? Colors.red.withValues(alpha: 0.8) : const Color(0xFF00F0FF).withValues(alpha: 0.8),
                foregroundColor: Colors.black,
              ),
              child: Text(state.isConnected ? l10n.disconnectDevice : l10n.connectDevice),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, CarState state) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildInfoItem(l10n.battery, "${state.carBattery}V", Icons.battery_charging_full, Colors.green),
        _buildInfoItem(l10n.distance, "${state.distance}cm", Icons.settings_input_antenna, Colors.blue),
        _buildInfoItem(l10n.mode, state.mode == 'MANUAL' ? l10n.manual : (state.mode == 'AUTO' ? l10n.auto : state.mode), Icons.settings, Colors.orange),
        _buildInfoItem(l10n.signal, "${state.wifiSignal}dBm", Icons.wifi, Colors.purple),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
