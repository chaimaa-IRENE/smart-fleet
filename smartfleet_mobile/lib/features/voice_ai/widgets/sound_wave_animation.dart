import 'dart:math';
import 'package:flutter/material.dart';

class SoundWaveAnimation extends StatefulWidget {
  final bool active;
  final Color color;

  const SoundWaveAnimation({
    super.key,
    this.active = false,
    this.color = const Color(0xFF667eea),
  });

  @override
  State<SoundWaveAnimation> createState() => _SoundWaveAnimationState();
}

class _SoundWaveAnimationState extends State<SoundWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const int _barCount = 5;
  final List<double> _heights = List.filled(_barCount, 0.1);
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _ctrl.addListener(() {
      if (widget.active) {
        setState(() {
          for (var i = 0; i < _barCount; i++) {
            _heights[i] = 0.15 + _rand.nextDouble() * 0.85;
          }
        });
      } else {
        setState(() {
          for (var i = 0; i < _barCount; i++) {
            _heights[i] = 0.1 + (_heights[i] - 0.1) * 0.9;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 6,
            height: 40 * _heights[i],
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.6),
                  widget.color,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          );
        }),
      ),
    );
  }
}
