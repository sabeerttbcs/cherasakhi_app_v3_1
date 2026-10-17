import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft emerald + gold light blobs behind content so glass surfaces glow.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: -140,
          right: -90,
          child: _blob(AppColors.blossom.withOpacity(isDark ? 0.20 : 0.16), 320),
        ),
        Positioned(
          top: 280,
          left: -140,
          child: _blob(AppColors.roseGoldLight.withOpacity(isDark ? 0.14 : 0.14), 300),
        ),
        Positioned(
          bottom: -120,
          right: -80,
          child: _blob(AppColors.berry.withOpacity(isDark ? 0.30 : 0.10), 280),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _blob(Color color, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      );
}
