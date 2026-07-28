import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedMicButton extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final VoidCallback onTap;

  const AnimatedMicButton({
    super.key,
    required this.isListening,
    this.isProcessing = false,
    required this.onTap,
  });

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isListening) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isProcessing ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) {
          final scale = _scale.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.isListening
                      ? [const Color(0xFFFF416C), const Color(0xFFFF4B2B)]
                      : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isListening
                        ? const Color(0xFFFF416C).withValues(alpha: 0.5)
                        : const Color(0xFF667eea).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: widget.isListening ? 5 : 2,
                  ),
                ],
              ),
              child: Icon(
                widget.isListening ? Icons.mic : Icons.mic_none,
                size: 48,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
