import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PremiumBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const PremiumBadge({
    super.key,
    required this.text,
    this.color,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  factory PremiumBadge.conforme({String text = 'Conforme'}) {
    return PremiumBadge(text: text, color: AppTheme.success);
  }

  factory PremiumBadge.nonConforme({String text = 'Non conforme'}) {
    return PremiumBadge(text: text, color: AppTheme.danger);
  }

  factory PremiumBadge.enCours({String text = 'En cours'}) {
    return PremiumBadge(text: text, color: const Color(0xFF2196F3));
  }

  factory PremiumBadge.aVerifier({String text = 'À vérifier'}) {
    return PremiumBadge(text: text, color: AppTheme.warning);
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? c.withValues(alpha: 0.2) : c.withValues(alpha: 0.1);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: isDark ? c : c.withValues(alpha: 0.9),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
