import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'control_page.dart';

class ControlEntryPage extends StatelessWidget {
  const ControlEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 100, color: Color(0xFF00F0FF)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                if (!state.isConnected) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          const SizedBox(width: 10),
                          Text(l10n.connectWarning),
                        ],
                      ),
                      content: Text(l10n.offlineWarning),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                // Switch to landscape before navigating
                await SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);

                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ControlPage()),
                  ).then((_) {
                    // Switch back to portrait when returning
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(l10n.startControl, style: const TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
