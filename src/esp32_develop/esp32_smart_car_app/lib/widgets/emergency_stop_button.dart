import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';

class EmergencyStopButton extends StatefulWidget {
  const EmergencyStopButton({super.key});

  @override
  State<EmergencyStopButton> createState() => _EmergencyStopButtonState();
}

class _EmergencyStopButtonState extends State<EmergencyStopButton> {
  Offset _offset = const Offset(0, 0);
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    
    if (!state.showEmergencyStop || !state.isConnected) {
      return const SizedBox.shrink();
    }

    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _offset = Offset(size.width - 70, size.height - 180);
      _initialized = true;
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        onTap: () {
          state.emergencyStop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('EMERGENCY STOP SENT'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Material(
          elevation: 8,
          shape: const CircleBorder(),
          color: Colors.redAccent,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
