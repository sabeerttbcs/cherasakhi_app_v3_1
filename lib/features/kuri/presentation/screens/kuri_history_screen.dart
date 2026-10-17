import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month_key.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../lottery_wheel/domain/entities/draw_record.dart';
import '../../../lottery_wheel/presentation/providers/wheel_providers.dart';
import '../../domain/entities/kuri_cycle.dart';
import '../../domain/entities/ledger_summary.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/payment.dart';
import '../providers/kuri_providers.dart';
import '../widgets/ledger_metrics_bento.dart';

/// Full historical ledger of the cycle, filterable by year and month.
class KuriHistoryScreen extends ConsumerStatefulWidget {
  const KuriHistoryScreen({super.key, required this.cycle});

  final KuriCycle cycle;

  @override
  ConsumerState<KuriHistoryScreen> createState() => _KuriHistoryScreenState();
}

class _KuriHistoryScreenState extends ConsumerState<KuriHistoryScreen> {
  late String _month = ref.read(effectiveMonthProvider);
  late int _year = MonthKey.year(_month);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cycle = widget.cycle;
    final years = cycle.months.map(MonthKey.year).toSet().toList()..sort();
    final monthsOfYear = cycle.months.where((m) => MonthKey.year(m) == _year).toList();

    final members = (ref.watch(membersProvider).valueOrNull ?? const <Member>[]).where((m) => m.isActive).toList();
    final paymentsAsync = ref.watch(paymentsProvider((cycleId: cycle.id, monthKey: _month)));
    final payments = paymentsAsync.valueOrNull ?? const <String, Payment>{};
    final draws = ref.watch(drawsProvider(cycle.id)).valueOrNull ?? const <DrawRecord>[];
    final summary = LedgerSummary.compute(members: members, payments: payments, installment: cycle.monthlyInstallment);
    final paid = members.where((m) => payments[m.id]?.paid ?? false).toList();
    final unpaid = members.where((m) => !(payments[m.id]?.paid ?? false)).toList();
    DrawRecord? monthDraw;
    for (final d in draws) {
      if (d.monthKey == _month) monthDraw = d;
    }

    return Scaffold(
      appBar: AppBar(title: Text('${cycle.name} · Ledger')),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final y in years)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$y'),
                        selected: y == _year,
                        onSelected: (_) => setState(() {
                          _year = y;
                          _month = cycle.months.firstWhere((m) => MonthKey.year(m) == y);
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in monthsOfYear)
                  ChoiceChip(
                    label: Text(MonthKey.short(m)),
                    selected: m == _month,
                    avatar: draws.any((d) => d.monthKey == m)
                        ? const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.roseGoldLight)
                        : null,
                    onSelected: (_) => setState(() => _month = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(MonthKey.label(_month), style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            LedgerMetricsBento(summary: summary),
            if (monthDraw != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                gradient: AppColors.roseGoldGradient,
                blur: false,
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pamparam winner', style: TextStyle(color: Colors.white70)),
                          Text(monthDraw.winnerName,
                              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    Text(formatMoney(monthDraw.amount),
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
            SectionHeader('Paid (${paid.length})'),
            _NameWrap(members: paid, color: AppColors.blossom),
            SectionHeader('Unpaid (${unpaid.length})'),
            _NameWrap(members: unpaid, color: AppColors.roseGold),
            SectionHeader('Winners timeline', subtitle: '${draws.length} of ${cycle.durationMonths} draws done'),
            for (final d in draws)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  blur: false,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: AppColors.roseGoldLight),
                      const SizedBox(width: 12),
                      Expanded(child: Text(d.winnerName, style: theme.textTheme.titleSmall)),
                      Text(MonthKey.label(d.monthKey), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NameWrap extends StatelessWidget {
  const _NameWrap({required this.members, required this.color});

  final List<Member> members;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in members)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('#${m.seatNo} ${m.name}', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
      ],
    );
  }
}
