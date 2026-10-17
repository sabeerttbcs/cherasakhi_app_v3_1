import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/profile_menu_button.dart';
import '../../domain/entities/event_models.dart';
import '../../../home/presentation/app_refresh.dart';
import '../providers/events_providers.dart';
import '../widgets/event_sheets.dart';
import 'event_detail_screen.dart';

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final events = ref.watch(eventsProvider);

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'new-fund',
              backgroundColor: AppColors.roseGold,
              foregroundColor: Colors.white,
              onPressed: () => showCreateEventSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New fund'),
            )
          : null,
      body: AmbientBackground(
        child: AppRefreshIndicator(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    Text('Tour & Party Wallet', style: theme.textTheme.headlineSmall),
                    Text('Isolated funds · who holds the cash', style: theme.textTheme.bodySmall),
                  ],
                ),
                actions: const [
                RefreshActionButton(),
                SizedBox(width: 8),
                Padding(padding: EdgeInsets.only(right: 12), child: ProfileMenuButton()),
              ],
              ),
              ...events.when<List<Widget>>(
                loading: () => [
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load funds', message: '$e'),
                  ),
                ],
                data: (list) => list.isEmpty
                    ? [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.luggage_rounded,
                            title: 'No event funds yet',
                            message: isAdmin
                                ? 'Create a fund for your next trip or celebration.'
                                : 'Your admin has not created any event funds yet.',
                          ),
                        ),
                      ]
                    : [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverList.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) => _EventCard(event: list[i]),
                          ),
                        ),
                      ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});

  final EventFund event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(eventLedgerProvider(event.id)).valueOrNull;
    return GlassCard(
      blur: false,
      gradient: AppColors.berryGradient,
      padding: const EdgeInsets.all(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.roseGoldGradient),
                child: Text(event.category.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    Text(
                      '${event.category.label}${event.isSettled ? ' · settled' : ''}',
                      style: const TextStyle(color: AppColors.roseGoldPale, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Collected', ledger?.collected),
              _stat('Spent', ledger?.spent),
              _stat('Balance', ledger?.balance, highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double? value, {bool highlight = false}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(
              value == null ? '—' : formatMoneyCompact(value),
              style: TextStyle(
                color: highlight ? AppColors.roseGoldLight : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
}
