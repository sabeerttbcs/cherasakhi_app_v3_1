import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/profile_menu_button.dart';
import '../../../home/presentation/app_refresh.dart';
import '../../domain/entities/quiz_models.dart';
import '../providers/quiz_providers.dart';
import '../widgets/quiz_format.dart';
import 'live_quiz_screen.dart';
import 'quiz_scheduler_screen.dart';

/// Live Quiz tab — open to every registered member.
class QuizHubScreen extends ConsumerWidget {
  const QuizHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final contests = ref.watch(quizContestsProvider);
    final now = ref.watch(serverNowProvider).valueOrNull ?? DateTime.now();

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'schedule-quiz',
              backgroundColor: AppColors.roseGold,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuizSchedulerScreen())),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Schedule quiz'),
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
                    Text('Live Quiz', style: theme.textTheme.headlineSmall),
                    Text('Fastest Finger First · open to all members', style: theme.textTheme.bodySmall),
                  ],
                ),
                actions: const [
                  RefreshActionButton(),
                  SizedBox(width: 8),
                  Padding(padding: EdgeInsets.only(right: 12), child: ProfileMenuButton()),
                ],
              ),
              ...contests.when<List<Widget>>(
                loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
                error: (e, _) => [
                  SliverFillRemaining(
                    child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load quizzes', message: '$e'),
                  ),
                ],
                data: (all) {
                  final visible = isAdmin ? all : all.where((c) => c.status != QuizStatus.cancelled).toList();
                  final live = visible.where((c) => c.phaseAt(now) == QuizPhase.live).toList();
                  final upcoming = visible.where((c) => c.phaseAt(now) == QuizPhase.scheduled).toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
                  final past = visible
                      .where((c) => c.phaseAt(now) == QuizPhase.ended || c.phaseAt(now) == QuizPhase.cancelled)
                      .toList();
                  if (visible.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.quiz_rounded,
                          title: 'No quizzes yet',
                          message: isAdmin
                              ? 'Schedule the first live quiz for the community.'
                              : 'You will be notified when the next quiz is scheduled.',
                        ),
                      ),
                    ];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      sliver: SliverList.list(
                        children: [
                          if (live.isNotEmpty) ...[
                            const SectionHeader('Live now'),
                            for (final c in live) _ContestCard(contest: c, now: now, isAdmin: isAdmin),
                          ],
                          if (upcoming.isNotEmpty) ...[
                            const SectionHeader('Upcoming'),
                            for (final c in upcoming) _ContestCard(contest: c, now: now, isAdmin: isAdmin),
                          ],
                          if (past.isNotEmpty) ...[
                            const SectionHeader('Results'),
                            for (final c in past) _ContestCard(contest: c, now: now, isAdmin: isAdmin),
                          ],
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContestCard extends ConsumerWidget {
  const _ContestCard({required this.contest, required this.now, required this.isAdmin});

  final QuizContest contest;
  final DateTime now;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = contest.phaseAt(now);
    final isLive = phase == QuizPhase.live;
    final r = contest.result;

    final subtitle = switch (phase) {
      QuizPhase.live => 'LIVE · ends in ${formatCountdown(contest.endTime.difference(now))}',
      QuizPhase.scheduled => 'Starts in ${formatCountdown(contest.startTime.difference(now))}',
      QuizPhase.cancelled => 'Cancelled',
      QuizPhase.ended => r == null
          ? 'Ended · tap to see the result'
          : r.hasWinner
              ? '🏆 ${r.winnerName} · ${r.correctCount}/${r.totalSubmissions} correct'
              : 'No correct answers · ${r.totalSubmissions} entries',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        blur: false,
        gradient: isLive
            ? const LinearGradient(colors: [Color(0xFF7A1A4A), Color(0xFF4A0E2E)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        borderColor: isLive ? AppColors.roseGoldLight : null,
        padding: const EdgeInsets.all(16),
        onTap: phase == QuizPhase.cancelled
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveQuizScreen(quizId: contest.id))),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLive ? AppColors.roseGoldGradient : null,
                color: isLive ? null : AppColors.blush,
              ),
              child: Icon(
                switch (phase) {
                  QuizPhase.live => Icons.sensors_rounded,
                  QuizPhase.scheduled => Icons.schedule_rounded,
                  QuizPhase.cancelled => Icons.event_busy_rounded,
                  QuizPhase.ended => Icons.emoji_events_rounded,
                },
                color: isLive ? Colors.white : AppColors.berry,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: quizTextStyle(
                      size: 16,
                      weight: FontWeight.w700,
                      color: isLive ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                  Text(
                    '${contest.category.isEmpty ? '' : '${contest.category} · '}${formatSchedule(contest.startTime)}',
                    style: TextStyle(fontSize: 11.5, color: isLive ? Colors.white60 : Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: isLive ? AppColors.roseGoldPale : AppColors.roseGold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin && phase == QuizPhase.scheduled)
              PopupMenuButton<String>(
                onSelected: (v) => _adminAction(context, ref, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'cancel', child: Text('Cancel quiz')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else
              Icon(Icons.chevron_right_rounded, color: isLive ? Colors.white70 : null),
          ],
        ),
      ),
    );
  }

  Future<void> _adminAction(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(quizRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'edit') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizSchedulerScreen(existing: contest)));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(action == 'cancel' ? 'Cancel this quiz?' : 'Delete this quiz?'),
        content: Text(action == 'cancel'
            ? 'Members will see it as cancelled.'
            : 'The quiz, its question and answer key are removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (action == 'cancel') {
        await repo.cancelContest(contest.id);
      } else {
        await repo.deleteContest(contest.id);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Not allowed: $e')));
    }
  }
}
