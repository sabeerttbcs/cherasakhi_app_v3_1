import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.highlight = false, this.size = 44});

  final String name;
  final bool highlight;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: highlight ? AppColors.berryGradient : null,
        color: highlight ? null : AppColors.roseGoldLight.withOpacity(0.16),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
          color: highlight ? AppColors.roseGoldPale : AppColors.roseGold,
        ),
      ),
    );
  }
}
