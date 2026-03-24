import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';

class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    if (!state.showEmergencyStop) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      right: 20,
      child: GestureDetector(
        onTap: () {
          state.sendCommand('{"cmd":"stop"}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('EMERGENCY STOP SENT'), backgroundColor: Colors.red),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}
