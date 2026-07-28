import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AuroraBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const AuroraBackground({
    super.key,
    required this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auroraColors = colors ??
        [
          AppTheme.primary.withValues(alpha: 0.3),
          AppTheme.secondary.withValues(alpha: 0.2),
          (isDark ? Colors.deepPurple : const Color(0xFF7C4DFF)).withValues(alpha: 0.15),
          AppTheme.accent.withValues(alpha: 0.1),
        ];

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _AuroraPainter(colors: auroraColors),
          ),
        ),
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final List<Color> colors;

  _AuroraPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    for (var i = 0; i < colors.length; i++) {
      final fraction = i / colors.length;
      final paint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (i.isEven ? -0.3 : 0.3) + (fraction * 0.6),
            -0.2 + (fraction * 0.6),
          ),
          radius: 0.8 + (fraction * 0.4),
          colors: [
            colors[i].withValues(alpha: 0.3 - (fraction * 0.15)),
            colors[i].withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..blendMode = BlendMode.screen;
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;
}
