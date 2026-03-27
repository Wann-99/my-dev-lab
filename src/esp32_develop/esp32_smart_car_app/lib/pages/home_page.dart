import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主控大屏',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 32),
            
            // Central Visual Display
            AspectRatio(
              aspectRatio: 1.2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: TechGridPainter(
                      rotation: _rotationController,
                      batteryPercentage: state.batteryPercentage,
                      isConnected: state.isConnected,
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.9),
                          const Color(0xFFF1F5F9).withOpacity(0.5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (state.isConnected ? Colors.green : Colors.red).withOpacity(0.15),
                          blurRadius: 25,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 0,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/car_model.png',
                        fit: BoxFit.cover, // Cover ensure it fills the circle after crop
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.directions_car_rounded,
                          size: 100,
                          color: state.isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatusCard(
                  '网络信号',
                  state.isConnected ? '${state.rssi} dBm' : '--',
                  Colors.blue,
                  Icons.wifi_rounded,
                ),
                _buildStatusCard(
                  '当前延迟',
                  state.isConnected ? '${state.latency} ms' : '--',
                  Colors.orange,
                  Icons.timer_rounded,
                ),
                _buildStatusCard(
                  '前方距离',
                  state.isConnected ? (state.radarDistance > 600 || state.radarDistance < 2 ? '盲区' : '${state.radarDistance.toStringAsFixed(1)} cm') : '--',
                  Colors.purple,
                  Icons.straighten_rounded,
                ),
                _buildModeCard(state),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(CarState state) {
    final String modeLabel;
    final Color modeColor;
    final IconData modeIcon;

    if (!state.isConnected) {
      modeLabel = '--';
      modeColor = const Color(0xFF94A3B8);
      modeIcon = Icons.settings_suggest_rounded;
    } else if (!state.isRemoteMode) {
      modeLabel = '本地手动';
      modeColor = Colors.green;
      modeIcon = Icons.wifi_rounded;
    } else if (!state.isAutoMode) {
      modeLabel = '远程手动';
      modeColor = Colors.orange;
      modeIcon = Icons.cloud_outlined;
    } else {
      modeLabel = '远程自动';
      modeColor = Colors.purple;
      modeIcon = Icons.smart_toy_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: state.isConnected ? Border.all(color: modeColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: modeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(modeIcon, size: 16, color: modeColor),
              ),
              const SizedBox(width: 10),
              const Text(
                '当前模式',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Text(
            modeLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: state.isConnected ? modeColor : const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title, 
                style: const TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B)
                )
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold, 
              color: const Color(0xFF1E293B), // Use dark color for value for better readability
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class TechGridPainter extends CustomPainter {
  final Animation<double> rotation;
  final int batteryPercentage;
  final bool isConnected;

  TechGridPainter({
    required this.rotation,
    required this.batteryPercentage,
    required this.isConnected,
  }) : super(repaint: rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    final gridPaint = Paint()
      ..color = const Color(0xFF29B6F6).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // 1. Draw background grid
    const step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
    
    // 2. Outer Ring (Meteor & Star Tail Effect)
    final meteorColor = isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final meteorRadius = radius * 0.85;
    const int meteorCount = 2;

    for (int i = 0; i < meteorCount; i++) {
      final double baseAngle = (rotation.value * 2 * math.pi) + (i * math.pi);
      
      // Draw 3 tail lines with different lengths and radii
      for (int j = 0; j < 3; j++) {
        final double tailRadius = meteorRadius + (j - 1) * 3.5;
        final double tailLength = (math.pi / 2.5) - (j * 0.15);
        final double opacity = 0.8 - (j * 0.25);
        
        final tailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - (j * 0.5)
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [
              meteorColor.withOpacity(0),
              meteorColor.withOpacity(opacity),
            ],
            stops: const [0.0, 1.0],
            transform: GradientRotation(baseAngle - tailLength),
          ).createShader(Rect.fromCircle(center: center, radius: tailRadius));

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: tailRadius),
          baseAngle - tailLength,
          tailLength,
          false,
          tailPaint,
        );
      }

      // Draw the Star at the head
      final starPos = Offset(
        center.dx + meteorRadius * math.cos(baseAngle),
        center.dy + meteorRadius * math.sin(baseAngle),
      );
      
      _drawStar(canvas, starPos, 7.0, Paint()..color = meteorColor..style = PaintingStyle.fill);
    }

    // 3. Inner Ring (Battery Fill)
    final innerRingBgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final batteryColor = _getBatteryColor(batteryPercentage);
    final innerRingFillPaint = Paint()
      ..color = batteryColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    // Draw background for battery ring
    canvas.drawCircle(center, radius * 0.75, innerRingBgPaint);

    // Draw battery fill arc
    final sweepAngle = (batteryPercentage / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.75),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      innerRingFillPaint,
    );

    // 4. Center Diffusion Glow
    final glowPaint = Paint()
      ..color = (isConnected ? Colors.green : Colors.red).withOpacity(0.08)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(center, radius * 0.55, glowPaint);
  }

  Color _getBatteryColor(int percentage) {
    if (percentage > 60) return Colors.green;
    if (percentage > 20) return Colors.orange;
    return Colors.red;
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final angle = math.pi / 5;
    for (int i = 0; i < 10; i++) {
      final r = (i % 2 == 0) ? radius : radius * 0.45;
      final currAngle = i * angle - math.pi / 2;
      final x = center.dx + r * math.cos(currAngle);
      final y = center.dy + r * math.sin(currAngle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDashedCircle(Canvas canvas, double x, double y, double radius, int segments, Paint paint) {
    const dashLength = 10.0;
    const gapLength = 5.0;
    final totalLength = 2 * math.pi * radius;
    final dashArc = (dashLength / totalLength) * 2 * math.pi;
    final gapArc = (gapLength / totalLength) * 2 * math.pi;
    
    for (int i = 0; i < segments; i++) {
      final startAngle = i * (dashArc + gapArc);
      canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: radius), startAngle, dashArc, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
