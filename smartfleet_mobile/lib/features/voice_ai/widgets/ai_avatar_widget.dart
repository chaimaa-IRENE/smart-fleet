import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class AiAvatarWidget extends StatefulWidget {
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;

  const AiAvatarWidget({
    super.key,
    this.isListening = false,
    this.isThinking = false,
    this.isSpeaking = false,
  });

  @override
  State<AiAvatarWidget> createState() => _AiAvatarWidgetState();
}

class _AiAvatarWidgetState extends State<AiAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    final isActive = widget.isListening || widget.isThinking || widget.isSpeaking;
    final color = widget.isListening
        ? AppTheme.accent
        : widget.isThinking
            ? AppTheme.warning
            : widget.isSpeaking
                ? AppTheme.success
                : AppTheme.primary;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final pulse = _pulse.value;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4 * (1 - pulse * 0.5)),
                      blurRadius: 20 + pulse * 20,
                      spreadRadius: 5 + pulse * 10,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100 + pulse * (isActive ? 8 : 0),
                height: 100 + pulse * (isActive ? 8 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.6),
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.6),
                      color,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    transform: GradientRotation(
                        DateTime.now().millisecondsSinceEpoch % 360 * pi / 180),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: _buildFace(color, isActive),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFace(Color color, bool active) {
    return CustomPaint(
      painter: _FacePainter(color: color, active: active),
      size: const Size(80, 80),
    );
  }
}

class _FacePainter extends CustomPainter {
  final Color color;
  final bool active;

  _FacePainter({required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyesPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - 14, center.dy - 6), 5, eyesPaint);
    canvas.drawCircle(Offset(center.dx + 14, center.dy - 6), 5, eyesPaint);

    if (active) {
      final smilePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final path = Path()
        ..moveTo(center.dx - 16, center.dy + 10)
        ..quadraticBezierTo(
            center.dx, center.dy + 22, center.dx + 16, center.dy + 10);
      canvas.drawPath(path, smilePaint);
    } else {
      final mouthPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(center.dx - 10, center.dy + 12),
        Offset(center.dx + 10, center.dy + 12),
        mouthPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.color != color || old.active != active;
}
