import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';

class FloatingStatusBall extends StatelessWidget {
  const FloatingStatusBall({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state.isConnected ? Colors.green : Colors.red,
        boxShadow: [
          BoxShadow(
            color: (state.isConnected ? Colors.green : Colors.red).withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
