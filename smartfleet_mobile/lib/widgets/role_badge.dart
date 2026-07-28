import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/app_constants.dart';

class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppConstants.roleLabels[role] ?? role,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return const Color(0xFFD32F2F);
      case 'RS':
      case 'RPF':
        return AppTheme.primary;
      case 'SL':
      case 'DRL':
        return const Color(0xFF1565C0);
      case 'CHAUFFEUR':
        return AppTheme.success;
      case 'PRESTATAIRE':
      case 'MAINTENANCE':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }
}
