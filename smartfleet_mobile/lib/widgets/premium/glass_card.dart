import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final Color? glowColor;
  final double blurIntensity;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.height,
    this.width,
    this.glowColor,
    this.blurIntensity = 30,
    this.margin,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final glow = glowColor ?? AppTheme.primary;

    return Container(
      height: height,
      width: width,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.radiusXL),
        child: BackdropFilter(
          filter: isDark
              ? ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.srcOver)
              : ColorFilter.mode(Colors.white.withValues(alpha: 0.3), BlendMode.srcOver),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.radiusXL),
                child: Padding(
                  padding: padding ?? AppSizes.cardPadding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
