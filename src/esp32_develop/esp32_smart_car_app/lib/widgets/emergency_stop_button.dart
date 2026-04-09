import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';

class EmergencyStopButton extends StatefulWidget {
  const EmergencyStopButton({super.key});

  @override
  State<EmergencyStopButton> createState() => _EmergencyStopButtonState();
}

class _EmergencyStopButtonState extends State<EmergencyStopButton>
    with SingleTickerProviderStateMixin {
  static const double _size = 72.0;

  // Drag offset from the default bottom-right anchor position
  double _offsetX = 0;
  double _offsetY = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    if (!state.showEmergencyStop) return const SizedBox.shrink();

    // Keep button inside screen when dragged (loose boundary based on screen size)
    final screen = MediaQuery.of(context).size;

    return Positioned(
      // Default anchor: bottom-right, above any navigation bar
      right: 20,
      bottom: 100,
      child: Transform.translate(
        offset: Offset(_offsetX, _offsetY),
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Apply delta; clamp to stay within screen bounds
              _offsetX = (_offsetX + details.delta.dx)
                  .clamp(-(screen.width - _size - 20), 20.0);
              _offsetY = (_offsetY + details.delta.dy)
                  .clamp(-screen.height * 0.75, screen.height * 0.2);
            });
          },
          onTap: () {
            HapticFeedback.heavyImpact();
            state.sendCommand('{"cmd":"move","vx":0,"vy":0,"vw":0}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️  紧急停止已发送'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.55),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 32),
                  SizedBox(height: 2),
                  Text(
                    'STOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
