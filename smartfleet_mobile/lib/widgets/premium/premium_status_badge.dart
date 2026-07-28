import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PremiumStatusBadge extends StatelessWidget {
  final String label;
  final String status;
  final double fontSize;

  const PremiumStatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.fontSize = 12,
  });

  Color get _color {
    switch (status.toUpperCase()) {
      case 'EN_ATTENTE':
      case 'PLANIFIEE':
        return AppTheme.warning;
      case 'EN_COURS':
      case 'OUVERT':
        return const Color(0xFF2196F3);
      case 'VALIDEE':
      case 'TERMINEE':
      case 'REPARE':
      case 'CLOTURE':
      case 'CONFORME':
        return AppTheme.success;
      case 'REFUSE':
      case 'REJETEE':
      case 'BLOQUEE':
      case 'EXPIRE':
      case 'NON_CONFORME':
        return AppTheme.danger;
      case 'BIENTOT_EXPIRE':
        return AppTheme.warning;
      case 'DISPONIBLE':
        return AppTheme.success;
      case 'AFFECTE':
        return const Color(0xFF9C27B0);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: isDark ? 0.3 : 0.25)),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? _color.withValues(alpha: 0.9) : _color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
