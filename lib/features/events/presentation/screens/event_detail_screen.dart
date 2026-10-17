import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_sheets.dart';
import '../widgets/event_split_dashboard.dart';
import '../widgets/participants_sheet.dart';
import '../widgets/split_expense_sheet.dart';
import '../widgets/expense_style.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.event});

  final EventFund event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final ledgerAsync = ref.watch(eventLedgerProvider(event.id));
    final expenses = ref.watch(expensesProvider(event.id)).valueOrNull ?? const <EventExpense>[];
    final contributions = ref.watch(contributionsProvider(event.id)).valueOrNull ?? const <Contribution>[];
    final transfers = ref.watch(transfersProvider(event.id)).valueOrNull ?? const <CashTransfer>[];
    final view = ref.watch(eventViewProvider(event.id));
    final canAddBill = canAddBillFor(ref, event.id);

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'event-entry',
              backgroundColor: AppColors.roseGold,
              foregroundColor: Colors.white,
              onPressed: () => _openActions(context, ledgerAsync.valueOrNull?.contributorCount ?? 1),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add entry'),
            )
          : canAddBill
              ? FloatingActionButton.extended(
                  heroTag: 'event-bill',
                  backgroundColor: AppColors.roseGold,
                  foregroundColor: Colors.white,
                  onPressed: () => showSplitExpenseSheet(context, event),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Add bill'),
                )
              : null,
      body: AmbientBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              foregroundColor: Colors.white,
              backgroundColor: AppColors.berry,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16, end: 16),
                title: Text(event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.berryGradient),
                  alignment: const Alignment(0.85, -0.1),
                  child: Text(event.category.emoji, style: const TextStyle(fontSize: 84)),
                ),
              ),
            ),
            ...ledgerAsync.when<List<Widget>>(
              loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                SliverFillRemaining(child: EmptyState(icon: Icons.error_outline, title: 'Error', message: '$e')),
              ],
              data: (ledger) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  sliver: SliverList.list(
                    children: [
                      EventViewToggle(eventId: event.id),
                      const SizedBox(height: 14),
                      if (view == 0) EventSplitDashboard(event: event) else ...[
                        _SummaryBento(ledger: ledger, event: event),
                        const SectionHeader(
                          'Who is holding the cash right now?',
                          subtitle: 'Received + handed-in − spent − handed-out',
                        ),
                        if (ledger.holders.isEmpty)
                          Text('No cash movements yet.', style: theme.textTheme.bodySmall)
                        else
                          for (final h in ledger.holders) _HolderTile(holder: h),
                        if (ledger.byCategory.isNotEmpty) ...[
                          const SectionHeader('Spending by category'),
                          _CategoryBreakdown(ledger: ledger),
                        ],
                        SectionHeader('Expenses (${expenses.length})'),
                        if (expenses.isEmpty) Text('No expenses logged.', style: theme.textTheme.bodySmall),
                        for (final e in expenses) _ExpenseTile(expense: e),
                        SectionHeader('Contributions (${contributions.length})'),
                        if (contributions.isEmpty) Text('No contributions yet.', style: theme.textTheme.bodySmall),
                        for (final c in contributions)
                          _LineTile(
                            icon: Icons.south_west_rounded,
                            color: AppColors.blossom,
                            title: c.memberName,
                            subtitle: 'Held by ${c.holderName} · ${formatDateTime(c.at)}'
                                '${c.note.isEmpty ? '' : ' · ${c.note}'}',
                            amount: '+${formatMoney(c.amount)}',
                          ),
                        if (transfers.isNotEmpty) ...[
                          const SectionHeader('Cash handovers'),
                          for (final t in transfers)
                            _LineTile(
                              icon: Icons.swap_horiz_rounded,
                              color: AppColors.roseGold,
                              title: '${t.fromName} → ${t.toName}',
                              subtitle: '${formatDateTime(t.at)}${t.note.isEmpty ? '' : ' · ${t.note}'}',
                              amount: formatMoney(t.amount),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openActions(BuildContext context, int defaultSplit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call_split_rounded, color: AppColors.berry),
              title: const Text('Add bill (auto-split)'),
              subtitle: const Text('Split equally across all participants'),
              onTap: () {
                Navigator.pop(sheetContext);
                showSplitExpenseSheet(context, event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_rounded, color: AppColors.roseGold),
              title: const Text('Participants'),
              subtitle: const Text('Add / remove people — every bill re-splits'),
              onTap: () {
                Navigator.pop(sheetContext);
                showParticipantsSheet(context, event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.south_west_rounded, color: AppColors.blossom),
              title: const Text('Add contribution'),
              subtitle: const Text('Member pays into the fund'),
              onTap: () {
                Navigator.pop(sheetContext);
                showContributionSheet(context, event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: AppColors.danger),
              title: const Text('Log expense (cash ledger)'),
              subtitle: const Text('Paid from pooled cash held by a member'),
              onTap: () {
                Navigator.pop(sheetContext);
                showExpenseSheet(context, event, defaultSplit: defaultSplit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.roseGold),
              title: const Text('Cash handover / settle-up payment'),
              subtitle: const Text('Money given from one member to another'),
              onTap: () {
                Navigator.pop(sheetContext);
                showTransferSheet(context, event);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SummaryBento extends StatelessWidget {
  const _SummaryBento({required this.ledger, required this.event});

  final EventLedger ledger;
  final EventFund event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(String label, double value, Color color, IconData icon) => Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(formatMoneyCompact(value),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );

    return Column(
      children: [
        GlassCard(
          blur: false,
          gradient: AppColors.roseGoldGradient,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fund balance (should be in hand)', style: TextStyle(color: Colors.white70)),
                    Text(formatMoney(ledger.balance),
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    if (event.perHeadTarget > 0)
                      Text('Per head: ${formatMoney(event.perHeadTarget)} · ${ledger.contributorCount} contributed',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile('Collected', ledger.collected, AppColors.blossom, Icons.south_west_rounded),
            const SizedBox(width: 10),
            tile('Spent', ledger.spent, AppColors.danger, Icons.north_east_rounded),
            const SizedBox(width: 10),
            tile('Holders', ledger.holders.length.toDouble(), AppColors.roseGold, Icons.people_alt_rounded),
          ],
        ),
      ],
    );
  }
}

class _HolderTile extends StatelessWidget {
  const _HolderTile({required this.holder});

  final HolderBalance holder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owed = holder.balance < 0;
    final color = owed ? AppColors.danger : AppColors.blossom;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            MemberAvatar(name: holder.name, highlight: !owed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holder.name, style: theme.textTheme.titleSmall),
                  Text(
                    'Got ${formatMoneyCompact(holder.received + holder.transferredIn)} · '
                    'Paid ${formatMoneyCompact(holder.spent + holder.transferredOut)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(holder.balance.abs()),
                    style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
                Text(owed ? 'fund owes her' : 'cash in hand',
                    style: theme.textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.ledger});

  final EventLedger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        children: [
          for (final c in ExpenseCategory.values)
            if ((ledger.byCategory[c] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(c.icon, color: c.color, size: 20),
                    const SizedBox(width: 10),
                    SizedBox(width: 104, child: Text(c.label, style: theme.textTheme.bodyMedium)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: ledger.spent <= 0 ? 0 : ledger.byCategory[c]! / ledger.spent,
                          color: c.color,
                          backgroundColor: c.color.withOpacity(0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(formatMoneyCompact(ledger.byCategory[c]!), style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final EventExpense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: e.receiptUrl == null ? null : () => _showReceipt(context, e.receiptUrl!),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: e.category.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(e.category.icon, color: e.category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text('${e.category.label} · paid by ${e.paidByName}', style: theme.textTheme.bodySmall),
                  Text('Split ${e.splitCount} ways · ${formatMoney(e.perHead)}/head · ${formatDate(e.at)}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('−${formatMoney(e.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w800)),
                if (e.receiptUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.roseGold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
          ),
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(amount, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
