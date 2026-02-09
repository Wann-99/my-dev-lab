import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';

class FloatingStatusBall extends StatefulWidget {
  const FloatingStatusBall({super.key});

  @override
  State<FloatingStatusBall> createState() => _FloatingStatusBallState();
}

class _FloatingStatusBallState extends State<FloatingStatusBall> {
  Offset _offset = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    Color color;
    String label;
    bool isBlinking = false;

    if (!state.isConnected) {
      color = Colors.red;
      label = l10n.offline;
    } else if (state.mode == "CHARGING") {
      color = Colors.yellow;
      label = l10n.charging;
    } else if (state.mode == "PATROL") {
      color = Colors.blue;
      label = l10n.patrolling;
    } else if (state.mode == "ALARM") {
      color = Colors.orange;
      label = l10n.alarm;
      isBlinking = true;
    } else {
      color = Colors.green;
      label = l10n.online;
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
        child: _buildBall(color, label, isBlinking),
      ),
    );
  }

  Widget _buildBall(Color color, String label, bool isBlinking, {double opacity = 1.0}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7 * opacity),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: opacity), width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3 * opacity), blurRadius: 8, spreadRadius: 2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BlinkingDot(color: color, isBlinking: isBlinking),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: opacity), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  final bool isBlinking;

  const _BlinkingDot({required this.color, required this.isBlinking});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.isBlinking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BlinkingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBlinking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isBlinking && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isBlinking ? widget.color.withValues(alpha: _controller.value) : widget.color,
          ),
        );
      },
    );
  }
}
