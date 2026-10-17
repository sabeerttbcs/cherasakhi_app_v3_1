import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/month_key.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/kuri_cycle.dart';
import '../providers/kuri_providers.dart';

class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key, required this.cycle});

  final KuriCycle cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(effectiveMonthProvider);
    final months = cycle.months;
    final idx = months.indexOf(month);

    void go(int i) {
      HapticFeedback.selectionClick();
      ref.read(selectedMonthProvider.notifier).state = months[i];
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      radius: 20,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: idx > 0 ? () => go(idx - 1) : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(month),
                children: [
                  Text(MonthKey.label(month), style: theme.textTheme.titleMedium),
                  Text(
                    'Month ${idx + 1} of ${months.length} · ${cycle.name}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: idx >= 0 && idx < months.length - 1 ? () => go(idx + 1) : null,
          ),
        ],
      ),
    );
  }
}
