import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month_key.dart';
import '../../../../core/widgets/gold_button.dart';
import '../providers/kuri_providers.dart';

Future<void> showStartCycleSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const StartCycleSheet(),
    );

class StartCycleSheet extends ConsumerStatefulWidget {
  const StartCycleSheet({super.key});

  @override
  ConsumerState<StartCycleSheet> createState() => _StartCycleSheetState();
}

class _StartCycleSheetState extends ConsumerState<StartCycleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Kuri ${DateTime.now().year}');
  final _installment = TextEditingController(text: '1000');
  late final _duration = TextEditingController(
    text: '${(ref.read(membersProvider).valueOrNull?.where((m) => m.isActive).length ?? 0).clamp(1, AppConstants.maxMembers)}',
  );
  String _start = MonthKey.current();

  @override
  void dispose() {
    _name.dispose();
    _installment.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(kuriRepositoryProvider)
        .startCycle(
          name: _name.text,
          startMonth: _start,
          durationMonths: int.parse(_duration.text),
          monthlyInstallment: double.parse(_installment.text),
          byUid: uid,
        )
        .catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not start cycle: $e')));
    });
    ref.read(selectedMonthProvider.notifier).state = _start;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final options = List.generate(8, (i) => MonthKey.add(MonthKey.current(), i - 3));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start a new Kuri cycle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Any currently active cycle will be closed.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Cycle name', prefixIcon: Icon(Icons.label_rounded)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _installment,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly installment per member',
                prefixText: '${AppConstants.currencySymbol} ',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _start,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Start month'),
                    items: [
                      for (final m in options) DropdownMenuItem(value: m, child: Text(MonthKey.label(m))),
                    ],
                    onChanged: (v) => setState(() => _start = v ?? _start),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Months'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '') ?? 0;
                      return n < 1 || n > 120 ? '1–120' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _installment,
              builder: (context, value, _) {
                final count = ref.read(membersProvider).valueOrNull?.where((m) => m.isActive).length ?? 0;
                final pot = (double.tryParse(value.text) ?? 0) * count;
                return Text('Monthly pot with $count members: ${formatMoney(pot)}',
                    style: Theme.of(context).textTheme.bodySmall);
              },
            ),
            const SizedBox(height: 20),
            GoldButton(label: 'START CYCLE', icon: Icons.rocket_launch_rounded, expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
