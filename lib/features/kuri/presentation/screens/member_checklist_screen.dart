import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/month_key.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/profile_menu_button.dart';
import '../../domain/entities/claim.dart';
import '../../domain/entities/kuri_cycle.dart';
import '../../domain/entities/ledger_summary.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/payment.dart';
import '../providers/kuri_providers.dart';
import '../widgets/ledger_metrics_bento.dart';
import '../widgets/member_form_sheet.dart';
import '../widgets/member_payment_tile.dart';
import '../widgets/month_switcher.dart';
import '../widgets/start_cycle_sheet.dart';
import '../../../home/presentation/app_refresh.dart';
import 'kuri_history_screen.dart';

enum _PayFilter { all, paid, unpaid }

class MemberChecklistScreen extends ConsumerStatefulWidget {
  const MemberChecklistScreen({super.key});

  @override
  ConsumerState<MemberChecklistScreen> createState() => _MemberChecklistScreenState();
}

class _MemberChecklistScreenState extends ConsumerState<MemberChecklistScreen> {
  final _search = TextEditingController();
  String _query = '';
  _PayFilter _filter = _PayFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final cycleAsync = ref.watch(activeCycleProvider);
    return Scaffold(
      body: AmbientBackground(
        child: cycleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load ledger', message: '$e'),
          data: (cycle) => cycle == null ? _NoCycle(isAdmin: isAdmin) : _ledger(context, cycle, isAdmin),
        ),
      ),
    );
  }

  Widget _ledger(BuildContext context, KuriCycle cycle, bool isAdmin) {
    final theme = Theme.of(context);
    final month = ref.watch(effectiveMonthProvider);
    final membersAsync = ref.watch(membersProvider);
    final paymentsAsync = ref.watch(paymentsProvider((cycleId: cycle.id, monthKey: month)));
    final claims = ref.watch(claimsProvider(cycle.id)).valueOrNull ?? const <Claim>[];
    final winnerIds = {for (final c in claims) c.memberId};

    final allMembers = membersAsync.valueOrNull ?? const <Member>[];
    final active = allMembers.where((m) => m.isActive).toList();
    // Admins also see inactive members (dimmed) so they can re-activate them.
    final listed = isAdmin ? [...active, ...allMembers.where((m) => !m.isActive)] : active;
    final payments = paymentsAsync.valueOrNull ?? const <String, Payment>{};
    final summary = LedgerSummary.compute(
      members: active,
      payments: payments,
      installment: cycle.monthlyInstallment,
    );

    bool isPaid(Member m) => payments[m.id]?.paid ?? false;
    final q = _query.trim().toLowerCase();
    final visible = listed.where((m) {
      if (_filter == _PayFilter.paid && !isPaid(m)) return false;
      if (_filter == _PayFilter.unpaid && (isPaid(m) || !m.isActive)) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) || m.phone.contains(q) || m.seatNo.toString() == q;
    }).toList(growable: false);
    final unpaid = active.where((m) => !isPaid(m)).toList(growable: false);
    final loading = !membersAsync.hasValue;

    return AppRefreshIndicator(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 72,
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.92),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kuri Ledger', style: theme.textTheme.headlineSmall),
                Text(AppConstants.appName, style: theme.textTheme.bodySmall),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Cycle history',
                icon: const Icon(Icons.history_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => KuriHistoryScreen(cycle: cycle)),
                ),
              ),
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Admin',
                  onSelected: (v) {
                    if (v == 'member') showMemberFormSheet(context);
                    if (v == 'cycle') showStartCycleSheet(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'member', child: Text('Add member')),
                    PopupMenuItem(value: 'cycle', child: Text('Start new cycle')),
                  ],
                ),
              const RefreshActionButton(),
            const SizedBox(width: 8),
            const Padding(padding: EdgeInsets.only(right: 12), child: ProfileMenuButton()),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  MonthSwitcher(cycle: cycle),
                  const SizedBox(height: 12),
                  LedgerMetricsBento(summary: summary),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, phone or seat #',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in _PayFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _PayFilter.all => 'All ${active.length}',
                                _PayFilter.paid => 'Paid ${summary.paidCount}',
                                _PayFilter.unpaid => 'Unpaid ${summary.unpaidCount}',
                              }),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.campaign_rounded, size: 18, color: AppColors.whatsapp),
                          label: const Text('Remind all unpaid'),
                          onPressed: () => _remindAll(unpaid, cycle, month),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            )
          else if (allMembers.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.group_add_rounded,
                title: 'No members yet',
                message: 'Add the ${AppConstants.maxMembers} members of your collective to begin.',
                action: isAdmin
                    ? GoldButton(label: 'ADD MEMBER', icon: Icons.person_add_rounded, onPressed: () => showMemberFormSheet(context))
                    : null,
              ),
            )
          else if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(icon: Icons.search_off_rounded, title: 'No matches', message: 'Try a different name or filter.'),
            )
          else
            SliverFixedExtentList(
              itemExtent: 78,
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final m = visible[i];
                  return MemberPaymentTile(
                    key: ValueKey(m.id),
                    member: m,
                    paid: isPaid(m),
                    isAdmin: isAdmin,
                    isWinner: winnerIds.contains(m.id),
                    onToggle: (v) => _toggle(cycle, month, m, v),
                    onRemind: () => _remind(m, cycle, month),
                    onLongPress: isAdmin ? () => showMemberFormSheet(context, member: m) : null,
                  );
                },
                childCount: visible.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  void _toggle(KuriCycle cycle, String month, Member m, bool paid) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(kuriRepositoryProvider)
        .setPayment(
          cycleId: cycle.id,
          monthKey: month,
          member: m,
          paid: paid,
          amount: cycle.monthlyInstallment,
          byUid: uid,
        )
        .catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update ${m.name}: $e')));
    });
  }

  Future<void> _remind(Member m, KuriCycle cycle, String month) async {
    final ok = await WhatsAppLauncher.send(
      phone: m.phone,
      message: WhatsAppLauncher.reminder(
        name: m.name,
        monthLabel: MonthKey.label(month),
        amount: cycle.monthlyInstallment,
        groupName: AppConstants.appName,
      ),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp is not available')));
    }
  }

  Future<void> _remindAll(List<Member> unpaid, KuriCycle cycle, String month) async {
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everyone has paid 🎉')));
      return;
    }
    await WhatsAppLauncher.send(
      message: WhatsAppLauncher.groupReminder(
        names: unpaid.map((m) => m.name).toList(),
        monthLabel: MonthKey.label(month),
        amount: cycle.monthlyInstallment,
        groupName: AppConstants.appName,
      ),
    );
  }
}

class _NoCycle extends StatelessWidget {
  const _NoCycle({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(padding: EdgeInsets.all(12), child: ProfileMenuButton()),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.account_balance_rounded,
              title: 'No active Kuri cycle',
              message: isAdmin
                  ? 'Add members, then start a cycle with the monthly installment amount.'
                  : 'Your admin has not started a Kuri cycle yet.',
              action: isAdmin
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showMemberFormSheet(context),
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Add member'),
                        ),
                        GoldButton(
                          label: 'START CYCLE',
                          icon: Icons.rocket_launch_rounded,
                          onPressed: () => showStartCycleSheet(context),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
