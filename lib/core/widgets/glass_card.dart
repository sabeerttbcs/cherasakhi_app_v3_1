import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-acrylic surface: 85% opacity + backdrop blur + hairline border.
/// Use `blur: false` inside long lists for 60fps scrolling.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.gradient,
    this.color,
    this.blur = true,
    this.onTap,
    this.onLongPress,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;
  final Color? color;
  final bool blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (isDark ? AppColors.nightSurface : Colors.white);
    final br = BorderRadius.circular(radius);

    Widget content = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? base.withOpacity(blur ? 0.85 : 1) : null,
          gradient: gradient,
          borderRadius: br,
          border: Border.all(
            color: borderColor ??
                (isDark ? Colors.white.withOpacity(0.08) : AppColors.berry.withOpacity(0.07)),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: br,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (blur) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.berry).withOpacity(isDark ? 0.30 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: br, child: content),
    );
  }
}
