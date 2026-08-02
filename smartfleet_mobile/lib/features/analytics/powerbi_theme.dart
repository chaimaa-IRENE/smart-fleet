import 'package:flutter/material.dart';

class PbiColors {
  static const blue = Color(0xFF3B82F6);
  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFF8B5CF6);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFEF4444);
  static const cyan = Color(0xFF06B6D4);
  static const pink = Color(0xFFEC4899);
  static const slate = Color(0xFF64748B);
  static const white = Color(0xFFFFFFFF);

  static Color color(String name) {
    switch (name) {
      case 'blue': return blue;
      case 'indigo': return indigo;
      case 'violet': return violet;
      case 'emerald': return emerald;
      case 'amber': return amber;
      case 'rose': return rose;
      case 'cyan': return cyan;
      case 'pink': return pink;
      case 'slate': return slate;
      default: return white;
    }
  }

  static Color ivms(double v) =>
      v >= 80 ? emerald : v >= 50 ? amber : rose;
}

const kChartColors = [
  PbiColors.blue, PbiColors.emerald, PbiColors.amber, PbiColors.rose,
  PbiColors.violet, PbiColors.cyan, PbiColors.pink, PbiColors.indigo,
];

const kStatusColors = {
  'ACTIF': PbiColors.emerald,
  'BLOQUE': PbiColors.rose,
  'IMMOBILISE': PbiColors.rose,
  'MAINTENANCE': PbiColors.amber,
  'EN_SERVICE': PbiColors.blue,
  'A_ARRET': PbiColors.rose,
  'CLOTURE': PbiColors.emerald,
  'RESOLU': PbiColors.emerald,
  'OUVERT': PbiColors.amber,
  'EN_COURS': PbiColors.blue,
  'EN_ATTENTE': PbiColors.amber,
  'ANNULE': PbiColors.slate,
  'CRITIQUE': PbiColors.rose,
  'BLOQUANT': PbiColors.rose,
  'MAJEURE': PbiColors.amber,
  'MINEURE': PbiColors.blue,
  'PREVENTIVE': PbiColors.blue,
  'CURATIVE': PbiColors.amber,
};

Color statusColor(String s) => kStatusColors[s] ?? PbiColors.slate;

Color colorWithAlpha(Color c, double a) => c.withValues(alpha: a);
