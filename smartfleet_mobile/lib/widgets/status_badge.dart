import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsets padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(String s) {
    switch (s.toUpperCase()) {
      case 'EN_ATTENTE':
        return 'En attente';
      case 'PRISE_EN_CHARGE':
        return 'Prise en charge';
      case 'EN_COURS':
      case 'EN_REPARATION':
        return 'En réparation';
      case 'EN_VALIDATION':
        return 'En validation';
      case 'TRAITE':
        return 'Traité';
      case 'RETOURNEE':
        return 'Retournée';
      case 'REFUSE':
        return 'Refusée';
      case 'CLOTURE':
        return 'Clôturée';
      case 'REJETEE':
        return 'Rejetée';
      case 'BLOQUEE':
        return 'Bloquée';
      case 'VALIDEE':
        return 'Validée';
      case 'PENDING':
        return 'En attente';
      case 'COMPLETE':
        return 'Terminé';
      case 'REPAIRE':
        return 'À réparer';
      case 'VALIDATED':
        return 'Validé';
      case 'REJECTED':
        return 'Rejeté';
      case 'ACTIF':
        return 'Actif';
      case 'INACTIF':
        return 'Inactif';
      case 'DETECTEE':
        return 'Détectée';
      case 'REPAREE':
        return 'Réparée';
      case 'NON_REPAREE':
        return 'Non réparable';
      case 'ANNULEE':
        return 'Annulée';
      default:
        return s;
    }
  }
}
