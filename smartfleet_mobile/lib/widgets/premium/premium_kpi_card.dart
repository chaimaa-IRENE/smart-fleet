import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';

class PremiumKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final double? trend;
  final VoidCallback? onTap;

  const PremiumKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppTheme.primary,
    this.subtitle,
    this.trend,
    this.onTap,
  });

  @override
  State<PremiumKpiCard> createState() => _PremiumKpiCardState();
}

class _PremiumKpiCardState extends State<PremiumKpiCard> with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _valueAnimController;
  late Animation<double> _scaleAnim;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
    _animateValue();
  }

  void _animateValue() {
    final raw = double.tryParse(widget.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    _valueAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _valueAnimController.addListener(() {
      setState(() => _displayValue = raw * _valueAnimController.value);
    });
    _valueAnimController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _valueAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPercent = widget.value.contains('%');

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: 0.85 + (0.15 * _scaleAnim.value),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            child: BackdropFilter(
              filter: ColorFilter.mode(
                isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.4),
                BlendMode.srcOver,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)]
                        : [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.7)],
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                ),
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(widget.icon, color: widget.color, size: 20),
                        ),
                        if (widget.trend != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (widget.trend! >= 0 ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 14,
                                  color: widget.trend! >= 0 ? AppTheme.success : AppTheme.danger,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.trend!.abs().toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: widget.trend! >= 0 ? AppTheme.success : AppTheme.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasPercent
                          ? '${_displayValue.toStringAsFixed(0)}%'
                          : _displayValue >= 1000
                              ? '${(_displayValue / 1000).toStringAsFixed(1)}k'
                              : _displayValue.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: isDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          color: isDark ? Colors.white.withValues(alpha: 0.4) : AppTheme.textSecondary.withValues(alpha: 0.8),
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
