import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final double? change;
  final bool loading;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.change,
    this.loading = false,
    this.onTap,
  });

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _valueAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _valueAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      listenable: _scaleAnim,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: GlassKpi(
          title: widget.title,
          value: widget.value,
          icon: widget.icon,
          color: color,
          subtitle: widget.subtitle,
          change: widget.change,
          loading: widget.loading,
          onTap: widget.onTap,
          animValue: _valueAnim.value,
          isDark: isDark,
        ),
      ),
    );
  }
}

class GlassKpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final double? change;
  final bool loading;
  final VoidCallback? onTap;
  final double animValue;
  final bool isDark;

  const GlassKpi({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.change,
    this.loading = false,
    this.onTap,
    required this.animValue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1 * animValue),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark
                      ? const Color(0xFF0B1220).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.75),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const Spacer(),
                        if (change != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (change! >= 0 ? AppTheme.success : AppTheme.danger)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  change! >= 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 12,
                                  color: change! >= 0 ? AppTheme.success : AppTheme.danger,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${change!.abs().toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: change! >= 0 ? AppTheme.success : AppTheme.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Opacity(
                        opacity: animValue,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : AppTheme.textSecondary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context, null);
}
