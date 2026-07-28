import 'package:flutter/material.dart';
import '../config/theme.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final double? change;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.change,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color ?? AppTheme.primary, size: 28),
                  const Spacer(),
                  if (change != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: change! >= 0
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            change! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 14,
                            color: change! >= 0
                                ? AppTheme.success
                                : AppTheme.danger,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${change!.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: change! >= 0
                                  ? AppTheme.success
                                  : AppTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary,),),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary,),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
