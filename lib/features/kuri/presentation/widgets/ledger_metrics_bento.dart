import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/ledger_summary.dart';

/// Bento grid: hero "Collected" tile + three mini metric tiles.
class LedgerMetricsBento extends StatelessWidget {
  const LedgerMetricsBento({super.key, required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      children: [
        GlassCard(
          blur: false,
          gradient: AppColors.berryGradient,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Collected this month',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: s.collected),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatMoney(v),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('of ${formatMoney(s.target)} target pool',
                        style: const TextStyle(color: AppColors.roseGoldPale, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressRing(progress: s.progress, label: '${s.paidCount}/${s.totalMembers}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                icon: Icons.savings_rounded,
                label: 'Target Pool',
                value: formatMoneyCompact(s.target),
                color: AppColors.berryMid,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniMetric(
                icon: Icons.trending_down_rounded,
                label: 'Deficit',
                value: formatMoneyCompact(s.deficit),
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniMetric(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Unpaid',
                value: '${s.unpaidCount}',
                color: AppColors.roseGold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.roseGoldLight),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: GoogleFonts.playfairDisplay(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                  const Text('Paid', style: TextStyle(color: AppColors.roseGoldPale, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Text(label, style: theme.textTheme.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}
