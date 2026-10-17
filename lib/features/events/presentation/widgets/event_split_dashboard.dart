import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/event_models.dart';
import '../../domain/split/split_engine.dart';
import '../../domain/split/trip_participant.dart';
import '../controllers/event_split_controller.dart';
import 'expense_style.dart';
import 'participants_sheet.dart';
import 'split_expense_sheet.dart';
import 'split_format.dart';

const _deepBerry = Color(0xFF4A0E2E);

/// 0 = Split & settle (default), 1 = Cash ledger (original view).
final eventViewProvider = StateProvider.autoDispose.family<int, String>((ref, eventId) => 0);

/// Segmented switch shown at the top of the event screen.
class EventViewToggle extends ConsumerWidget {
  const EventViewToggle({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(eventViewProvider(eventId));
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, icon: Icon(Icons.calculate_rounded), label: Text('Split & settle')),
        ButtonSegment(value: 1, icon: Icon(Icons.account_balance_wallet_rounded), label: Text('Cash ledger')),
      ],
      selected: {view},
      onSelectionChanged: (s) => ref.read(eventViewProvider(eventId).notifier).state = s.first,
    );
  }
}

/// Event Expense Dashboard: trip cost, live per-person share, who owes /
/// gets back, settle-up plan, all bills, WhatsApp summary.
class EventSplitDashboard extends ConsumerWidget {
  const EventSplitDashboard({super.key, required this.event});

  final EventFund event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(eventSplitControllerProvider(event.id));
    final controller = ref.read(eventSplitControllerProvider(event.id).notifier);
    final user = ref.watch(appUserProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final isAdmin = user?.isAdmin ?? false;
    final myPid = participantIdFor(user);
    final canAddBill = isAdmin || s.isActiveParticipant(myPid);
    final theme = Theme.of(context);

    if (s.loading) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    }
    final sum = s.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewHero(summary: sum),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, child: FadeTransition(opacity: anim, child: child)),
          child: s.changeNote == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(s.changeNote),
                  padding: const EdgeInsets.only(top: 10),
                  child: _ChangeNote(text: s.changeNote!),
                ),
        ),
        if (sum.activeCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _InfoCard(
              icon: Icons.group_add_rounded,
              text: isAdmin
                  ? 'Add the people going on this trip. Every bill is split equally between them, and the split updates automatically when someone joins or leaves.'
                  : 'No participants yet. Join the trip to see your share.',
              action: isAdmin
                  ? TextButton.icon(
                      onPressed: () => showParticipantsSheet(context, event),
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add participants'),
                    )
                  : null,
            ),
          ),
        if (!isAdmin && myPid != null && !s.isListed(myPid))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _InfoCard(
              icon: Icons.luggage_rounded,
              text: 'Going on this trip? Join to share the cost and log bills you pay.',
              action: FilledButton.icon(
                onPressed: () => _join(context, controller),
                icon: const Icon(Icons.how_to_reg_rounded),
                label: const Text('Join this trip'),
              ),
            ),
          ),
        if (sum.hasOutsidePayers)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _InfoCard(
              icon: Icons.info_outline_rounded,
              text: 'Some bills were paid by people who are not on the participant list. They are credited what they paid but have no share. Add them as participants if they are on the trip.',
            ),
          ),

        // ── balances ──
        SectionHeader(
          'Paid vs share',
          subtitle: 'Net = paid upfront − fair share',
          trailing: isAdmin
              ? TextButton.icon(
                  onPressed: () => showParticipantsSheet(context, event),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: Text('Participants (${sum.activeCount})'),
                )
              : null,
        ),
        if (sum.balances.isEmpty)
          Text('No one yet.', style: theme.textTheme.bodySmall)
        else
          for (final b in sum.balances) _BalanceTile(balance: b, isMe: b.id == myPid),

        // ── settle up ──
        if (sum.settlementPlan.isNotEmpty) ...[
          SectionHeader('Settle-up plan', subtitle: '${sum.settlementPlan.length} payment(s) clear every balance'),
          GlassCard(
            blur: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final step in sum.settlementPlan)
                  _SettleRow(
                    step: step,
                    onMarkPaid: isAdmin ? () => _markPaid(context, controller, step) : null,
                  ),
              ],
            ),
          ),
        ],

        // ── bills ──
        SectionHeader(
          'Bills (${s.expenses.length})',
          subtitle: 'Each bill is split across all ${sum.activeCount} current participants',
          trailing: canAddBill
              ? TextButton.icon(
                  onPressed: () => showSplitExpenseSheet(context, event),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add bill'),
                )
              : null,
        ),
        if (s.expenses.isEmpty)
          Text('No bills yet. Add the first one: bus, food, stay…', style: theme.textTheme.bodySmall)
        else
          for (final e in s.expenses)
            _BillTile(
              expense: e,
              perPersonPaise: sum.activeCount == 0 ? 0 : toPaise(e.amount) / sum.activeCount,
              canDelete: isAdmin || (uid != null && e.createdBy == uid),
              onDelete: () => _deleteBill(context, controller, e),
            ),

        const SizedBox(height: 18),
        GoldButton(
          label: 'SHARE EXPENSE SUMMARY',
          icon: Icons.share_rounded,
          expand: true,
          onPressed: s.expenses.isEmpty
              ? null
              : () async {
                  HapticFeedback.lightImpact();
                  final ok = await WhatsAppLauncher.send(message: controller.whatsappSummary(event));
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp is not available')));
                  }
                },
        ),
      ],
    );
  }

  Future<void> _join(BuildContext context, EventSplitController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.joinTrip();
      messenger.showSnackBar(const SnackBar(content: Text('You joined the trip. Shares updated for everyone.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not join: $e')));
    }
  }

  Future<void> _markPaid(BuildContext context, EventSplitController controller, SettlementStep step) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Record payment?'),
        content: Text('${step.fromName} paid ${formatPaise(step.amountPaise)} to ${step.toName}. '
            'Both balances will update.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Mark paid')),
        ],
      ),
    );
    if (ok != true) return;
    await controller.recordSettlement(step);
  }

  Future<void> _deleteBill(BuildContext context, EventSplitController controller, EventExpense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete “${e.description}”?'),
        content: Text('${formatMoney(e.amount)} paid by ${e.paidByName}. Everyone’s share is recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    controller.deleteBill(e.id).catchError((Object err) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $err')));
    });
  }
}

// ───────────────────────────── pieces ─────────────────────────────

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({required this.summary});

  final SplitSummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      gradient: const LinearGradient(
        colors: [Color(0xFF7A1A4A), _deepBerry, Color(0xFF2A0619)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total trip cost', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          _AnimatedPaise(
            paise: summary.totalCostPaise.toDouble(),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.roseGoldGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current per-person share', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                      _AnimatedPaise(
                        paise: summary.perPersonPaise,
                        exact: true,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text(
                  '÷ ${summary.activeCount}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.groups_rounded, '${summary.activeCount} participants'),
              _chip(Icons.receipt_long_rounded, '${summary.billCount} bills'),
              _chip(Icons.handshake_rounded,
                  summary.settlementPlan.isEmpty ? 'All settled' : '${summary.settlementPlan.length} payments to settle'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.roseGoldPale.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.roseGoldPale),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Counts smoothly to the new value whenever the split changes.
class _AnimatedPaise extends StatelessWidget {
  const _AnimatedPaise({required this.paise, required this.style, this.exact = false});

  final double paise;
  final TextStyle style;
  final bool exact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: paise),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(formatPaise(v, exact: exact), style: style),
      ),
    );
  }
}

class _ChangeNote extends StatelessWidget {
  const _ChangeNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.roseGoldLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.autorenew_rounded, color: AppColors.berry, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Recalculated: $text',
                style: const TextStyle(color: AppColors.berry, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.roseGold),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance, required this.isMe});

  final ParticipantBalance balance;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = balance;
    final style = NetStatusStyle.of(b.status);
    final tag = !b.isParticipant
        ? 'not a participant'
        : !b.isActive
            ? 'removed'
            : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        borderColor: isMe ? AppColors.blossom : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            MemberAvatar(name: b.name, highlight: b.status == NetStatus.getsBack, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.name}${isMe ? ' (you)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    'Paid ${formatPaise(b.paidUpfrontPaise)} · Share ${formatPaise(b.shareDuePaise, exact: true)}'
                    '${tag == null ? '' : ' · $tag'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (b.poolAdjustmentPaise != 0)
                    Text(
                      'incl. pool cash ${b.poolAdjustmentPaise > 0 ? '+' : '−'}${formatPaise(b.poolAdjustmentPaise.abs())}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _NetChip(balance: b, style: style),
          ],
        ),
      ),
    );
  }
}

class _NetChip extends StatelessWidget {
  const _NetChip({required this.balance, required this.style});

  final ParticipantBalance balance;
  final NetStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(style.malayalam,
              style: GoogleFonts.notoSansMalayalam(color: style.color, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 13, color: style.color),
              const SizedBox(width: 3),
              Text(style.englishLabel(balance.netPaise),
                  style: TextStyle(color: style.color, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettleRow extends StatelessWidget {
  const _SettleRow({required this.step, this.onMarkPaid});

  final SettlementStep step;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: step.fromName, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                const TextSpan(text: '  →  '),
                TextSpan(text: step.toName, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF047857))),
              ]),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(formatPaise(step.amountPaise), style: theme.textTheme.titleSmall),
          if (onMarkPaid != null)
            IconButton(
              tooltip: 'Mark as paid',
              onPressed: onMarkPaid,
              icon: const Icon(Icons.task_alt_rounded, color: AppColors.roseGold),
            ),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.expense,
    required this.perPersonPaise,
    required this.canDelete,
    required this.onDelete,
  });

  final EventExpense expense;
  final double perPersonPaise;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        padding: const EdgeInsets.all(12),
        onLongPress: canDelete ? onDelete : null,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: e.category.color.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
              child: Icon(e.category.icon, color: e.category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text('Paid by ${e.paidByName} · ${formatDate(e.at)}', style: theme.textTheme.bodySmall),
                  Text('${formatPaise(perPersonPaise, exact: true)} per person now',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.roseGold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(e.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            if (canDelete)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete bill',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }

}

/// Re-exported for the event screen's FAB.
bool canAddBillFor(WidgetRef ref, String eventId) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user?.isAdmin ?? false) return true;
  return ref.watch(eventSplitControllerProvider(eventId)).isActiveParticipant(participantIdFor(user));
}

/// Participants of a trip, active first (for pickers).
List<TripParticipant> sortedParticipants(List<TripParticipant> list) => [...list]
  ..sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
