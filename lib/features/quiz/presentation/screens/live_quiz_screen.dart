import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/quiz_countdown_alarm.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/quiz_models.dart';
import '../../domain/usecases/answer_tools.dart';
import '../../domain/usecases/quiz_evaluation.dart';
import '../controllers/live_quiz_controller.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/quiz_format.dart';
import '../widgets/winner_announcement_modal.dart';

class LiveQuizScreen extends ConsumerStatefulWidget {
  const LiveQuizScreen({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends ConsumerState<LiveQuizScreen> {
  final _answerText = TextEditingController();
  /// Final-minute ticks, driven by the server-corrected clock.
  late final QuizCountdownAlarm _alarm = QuizCountdownAlarm(clock: () => _controller.serverNow);
  String? _selectedOption;
  bool _announced = false;

  @override
  void dispose() {
    _alarm.stop();
    _answerText.dispose();
    super.dispose();
  }

  LiveQuizController get _controller => ref.read(liveQuizControllerProvider(widget.quizId).notifier);

  /// Final-minute ticking only for members who still have to answer.
  void _syncAlarm(LiveQuizState s, bool canPlay) {
    final shouldRun = s.phase == QuizPhase.live && !s.hasSubmitted && canPlay && s.contest != null;
    if (shouldRun && !_alarm.isRunning) {
      _alarm.start(endsAt: s.contest!.endTime, quizTitle: s.contest!.title);
    } else if (!shouldRun && _alarm.isRunning) {
      _alarm.stop();
    }
  }

  Future<void> _confirmAndSubmit(String answer) async {
    final text = answer.trim();
    if (text.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Submit your answer?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“$text”', style: quizTextStyle(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('You can answer only once. The fastest correct answer wins.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    await _controller.submit(text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = liveQuizControllerProvider(widget.quizId);
    final s = ref.watch(provider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final canPlay = user?.canPlayQuiz ?? false;

    ref.listen<LiveQuizState>(provider, (prev, next) {
      // One-off messages → snackbar.
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.message!)));
        _controller.clearMessage();
      }
      // Entering the final crunch → strong haptic.
      if (prev != null && prev.phase == QuizPhase.live && next.phase == QuizPhase.live &&
          prev.tone != TimerTone.critical && next.tone == TimerTone.critical) {
        HapticFeedback.heavyImpact();
      }
      // Result just became available → announce once.
      if (!_announced && next.outcome != null && next.contest != null && next.phase == QuizPhase.ended) {
        final endedAgo = _controller.serverNow.difference(next.contest!.endTime);
        _announced = true;
        if (endedAgo < const Duration(hours: 2)) {
          showWinnerAnnouncement(context, contest: next.contest!, outcome: next.outcome!);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAlarm(s, canPlay);
    });

    final contest = s.contest;
    return Scaffold(
      appBar: AppBar(title: Text(contest?.title ?? 'Live Quiz', overflow: TextOverflow.ellipsis)),
      body: AmbientBackground(
        child: s.loading
            ? const Center(child: CircularProgressIndicator())
            : contest == null
                ? const EmptyState(icon: Icons.quiz_outlined, title: 'Quiz not found', message: 'It may have been deleted.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                    children: [
                      _HeaderCard(contest: contest),
                      const SizedBox(height: 18),
                      ...switch (s.phase) {
                        QuizPhase.cancelled => <Widget>[
                            const EmptyState(
                              icon: Icons.event_busy_rounded,
                              title: 'This quiz was cancelled',
                              message: 'Watch for the next one!',
                            ),
                          ],
                        QuizPhase.scheduled => _scheduled(s),
                        QuizPhase.live => _live(s, canPlay, user?.isAdmin ?? false),
                        QuizPhase.ended => _ended(s, user?.uid),
                      },
                    ],
                  ),
      ),
    );
  }

  // ───────────────────────────── phases ─────────────────────────────

  List<Widget> _scheduled(LiveQuizState s) {
    final c = s.contest!;
    return [
      Center(
        child: CountdownRing(remaining: s.remaining, fraction: 1, tone: TimerTone.calm, caption: 'STARTS IN', size: 190),
      ),
      const SizedBox(height: 22),
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _bullet(Icons.lock_clock_rounded, 'The question appears at ${formatClock(c.startTime)}.'),
            _bullet(Icons.timer_rounded, 'Answers are accepted until ${formatClock(c.endTime)}. The quiz runs the full time.'),
            _bullet(Icons.bolt_rounded, 'Fastest Finger First: the earliest correct answer wins.'),
            _bullet(Icons.looks_one_rounded, 'One answer per member, no changes after submitting.'),
            _bullet(Icons.verified_user_rounded, 'The answer is sealed and revealed only at the end time.'),
          ],
        ),
      ),
    ];
  }

  List<Widget> _live(LiveQuizState s, bool canPlay, bool isAdmin) {
    final c = s.contest!;
    final q = s.question;
    return [
      Center(
        child: CountdownRing(
          remaining: s.remaining,
          fraction: s.fractionRemaining,
          tone: s.tone,
          caption: 'TIME LEFT',
          size: 176,
        ),
      ),
      const SizedBox(height: 6),
      Center(child: Text('Closes at ${formatClock(c.endTime)}', style: Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height: 16),
      if (q == null)
        GlassCard(
          child: Row(
            children: [
              if (!s.questionUnavailable)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                const Icon(Icons.cloud_off_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s.questionUnavailable
                    ? 'Could not load the question. Check your connection and reopen this screen.'
                    : 'Loading question…'),
              ),
            ],
          ),
        )
      else
        _QuestionCard(question: q),
      const SizedBox(height: 16),
      if (isAdmin)
        _AdminLivePanel(count: s.submissionCount)
      else if (s.hasSubmitted)
        _RecordedCard(submission: s.mySubmission!)
      else if (canPlay && q != null)
        ..._answerInput(q, s),
    ];
  }

  List<Widget> _answerInput(QuizQuestion q, LiveQuizState s) {
    if (q.mode == AnswerMode.options) {
      return [
        for (var i = 0; i < q.options.length; i++)
          _OptionTile(
            index: i,
            text: q.options[i],
            selected: _selectedOption == q.options[i],
            onTap: s.submitting ? null : () => setState(() => _selectedOption = q.options[i]),
          ),
        const SizedBox(height: 14),
        GoldButton(
          label: s.submitting ? 'SUBMITTING…' : 'SUBMIT ANSWER',
          icon: Icons.send_rounded,
          loading: s.submitting,
          expand: true,
          onPressed: _selectedOption == null ? null : () => _confirmAndSubmit(_selectedOption!),
        ),
      ];
    }
    return [
      GlassCard(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _answerText,
          maxLength: 200,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          style: quizTextStyle(size: 18, weight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'Your answer / നിങ്ങളുടെ ഉത്തരം',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => _confirmAndSubmit(v),
        ),
      ),
      const SizedBox(height: 14),
      GoldButton(
        label: s.submitting ? 'SUBMITTING…' : 'SUBMIT ANSWER',
        icon: Icons.send_rounded,
        loading: s.submitting,
        expand: true,
        onPressed: _answerText.text.trim().isEmpty ? null : () => _confirmAndSubmit(_answerText.text),
      ),
    ];
  }

  List<Widget> _ended(LiveQuizState s, String? myUid) {
    final c = s.contest!;
    final o = s.outcome;
    if (o == null) {
      return [
        GlassCard(
          child: Column(
            children: [
              const Icon(Icons.lock_rounded, size: 40, color: AppColors.roseGold),
              const SizedBox(height: 10),
              Text('Submissions locked', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (s.evaluating) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text('ഫലം കണക്കാക്കുന്നു… (Evaluating results)', style: quizTextStyle(size: 14)),
              ] else
                const Text('Results will appear when you are back online.'),
            ],
          ),
        ),
      ];
    }

    final mine = s.mySubmission;
    final myRank = myUid == null ? null : o.rankOf(myUid);
    return [
      _ResultHero(contest: c, outcome: o),
      const SizedBox(height: 12),
      if (mine != null) _MyResultCard(submission: mine, rank: myRank, correct: o.correctIds.contains(mine.userId)),
      if (s.question != null) ...[
        const SizedBox(height: 12),
        _QuestionCard(
          question: s.question!,
          revealAnswer: o.correctAnswer,
          myAnswer: mine?.submittedAnswer,
        ),
      ],
      if (o.fastestCorrect.isNotEmpty) ...[
        SectionHeader('Fastest correct answers', subtitle: '${o.correctCount} correct of ${o.totalSubmissions} entries'),
        for (var i = 0; i < o.fastestCorrect.length && i < 10; i++)
          _RankTile(rank: i + 1, submission: o.fastestCorrect[i], start: c.startTime, isMe: o.fastestCorrect[i].userId == myUid),
      ],
      const SizedBox(height: 16),
      GoldButton(
        label: 'VIEW WINNER CARD',
        icon: Icons.emoji_events_rounded,
        expand: true,
        onPressed: () => showWinnerAnnouncement(context, contest: c, outcome: o),
      ),
    ];
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.roseGold),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

// ───────────────────────────── pieces ─────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.contest});

  final QuizContest contest;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      gradient: const LinearGradient(
        colors: [Color(0xFF7A1A4A), Color(0xFF4A0E2E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contest.category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.roseGoldPale.withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.roseGoldLight.withOpacity(0.5)),
              ),
              child: Text(contest.category, style: quizTextStyle(size: 12, weight: FontWeight.w600, color: AppColors.roseGoldPale, height: 1.3)),
            ),
          const SizedBox(height: 10),
          Text(contest.title, style: quizTextStyle(size: 21, weight: FontWeight.w800, color: Colors.white, height: 1.35)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.roseGoldLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${formatSchedule(contest.startTime)} → ${formatClock(contest.endTime)}'
                  '  (${contest.duration.inMinutes} min)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, this.revealAnswer, this.myAnswer});

  final QuizQuestion question;
  final String? revealAnswer;
  final String? myAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUESTION',
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.roseGold, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(question.text, style: quizTextStyle(size: 19, weight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          if (revealAnswer != null && question.mode == AnswerMode.options) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < question.options.length; i++)
              _OptionTile(
                index: i,
                text: question.options[i],
                selected: myAnswer != null && normalizeAnswer(myAnswer!) == normalizeAnswer(question.options[i]),
                reveal: normalizeAnswer(question.options[i]) == normalizeAnswer(revealAnswer!)
                    ? _Reveal.correct
                    : (myAnswer != null && normalizeAnswer(myAnswer!) == normalizeAnswer(question.options[i]))
                        ? _Reveal.wrong
                        : _Reveal.none,
              ),
          ],
        ],
      ),
    );
  }
}

enum _Reveal { none, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.index, required this.text, required this.selected, this.onTap, this.reveal = _Reveal.none});

  final int index;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final _Reveal reveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = switch (reveal) {
      _Reveal.correct => const Color(0xFF059669),
      _Reveal.wrong => AppColors.danger,
      _Reveal.none => selected ? AppColors.berry : AppColors.roseGold,
    };
    final active = selected || reveal != _Reveal.none;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(isDark ? 0.22 : 0.10) : (isDark ? AppColors.nightSurface : Colors.white).withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? accent : accent.withOpacity(0.25), width: active ? 2 : 1),
          boxShadow: [if (selected && reveal == _Reveal.none) BoxShadow(color: accent.withOpacity(0.25), blurRadius: 16)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? accent : Colors.transparent,
                      border: Border.all(color: accent, width: 1.6),
                    ),
                    child: reveal == _Reveal.correct
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : reveal == _Reveal.wrong
                            ? const Icon(Icons.close_rounded, color: Colors.white, size: 20)
                            : Text(
                                String.fromCharCode(65 + index),
                                style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : accent),
                              ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(text, style: quizTextStyle(size: 17, weight: FontWeight.w600, color: theme.colorScheme.onSurface, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordedCard extends StatelessWidget {
  const _RecordedCard({required this.submission});

  final QuizSubmission submission;

  @override
  Widget build(BuildContext context) {
    final pending = submission.pending;
    return GlassCard(
      borderColor: const Color(0xFF059669).withOpacity(0.5),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(pending ? Icons.cloud_upload_rounded : Icons.task_alt_rounded,
              size: 46, color: pending ? AppColors.roseGold : const Color(0xFF059669)),
          const SizedBox(height: 10),
          Text(
            'നിങ്ങളുടെ ഉത്തരം രേഖപ്പെടുത്തി. സമയം പൂർത്തിയാകുമ്പോൾ ഫലം പ്രഖ്യാപിക്കും',
            textAlign: TextAlign.center,
            style: quizTextStyle(size: 16.5, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '(Your answer is recorded. Result will be announced at scheduled end time)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.blush, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text('Your answer', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.berry)),
                Text(submission.submittedAnswer,
                    textAlign: TextAlign.center, style: quizTextStyle(size: 17, weight: FontWeight.w700, color: AppColors.berry)),
                const SizedBox(height: 4),
                Text(
                  pending ? 'Sending… (waiting for the server time-stamp)' : 'Recorded at ${formatPreciseTime(submission.submittedAt)}',
                  style: const TextStyle(color: AppColors.roseGold, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLivePanel extends StatelessWidget {
  const _AdminLivePanel({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded, color: AppColors.roseGold, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${count ?? '—'} submissions so far', style: Theme.of(context).textTheme.titleMedium),
                Text('You are hosting this quiz, so you cannot answer. The winner is evaluated automatically at the end time.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.contest, required this.outcome});

  final QuizContest contest;
  final QuizOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final w = outcome.winner;
    return GlassCard(
      blur: false,
      gradient: AppColors.roseGoldGradient,
      padding: const EdgeInsets.all(18),
      onTap: () => showWinnerAnnouncement(context, contest: contest, outcome: outcome),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w == null ? 'No correct answers' : 'Winner · Fastest Finger First',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                if (w != null)
                  Text(w.userName, style: quizTextStyle(size: 22, weight: FontWeight.w800, color: Colors.white, height: 1.3)),
                Text('Answer: ${outcome.correctAnswer}',
                    style: quizTextStyle(size: 14, weight: FontWeight.w600, color: Colors.white, height: 1.4)),
                if (w != null)
                  Text('Submitted at ${formatPreciseTime(w.submittedAt)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (outcome.sealVerified == true)
            const Tooltip(
              message: 'Answer matches the seal published before the start',
              child: Icon(Icons.verified_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _MyResultCard extends StatelessWidget {
  const _MyResultCard({required this.submission, required this.rank, required this.correct});

  final QuizSubmission submission;
  final int? rank;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF059669) : AppColors.danger;
    return GlassCard(
      borderColor: color.withOpacity(0.5),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? (rank == 1 ? 'You won! 🎉' : 'Correct! Rank #$rank among correct answers') : 'Not correct this time',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
                ),
                Text('Your answer: ${submission.submittedAnswer}', style: quizTextStyle(size: 14)),
                if (!submission.pending)
                  Text('Recorded at ${formatPreciseTime(submission.submittedAt)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.rank, required this.submission, required this.start, required this.isMe});

  final int rank;
  final QuizSubmission submission;
  final DateTime start;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => const Color(0xFFD4A017),
      2 => const Color(0xFF9CA3AF),
      3 => const Color(0xFFB87333),
      _ => AppColors.roseGoldLight,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        radius: 18,
        borderColor: isMe ? AppColors.blossom : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: medal.withOpacity(0.18), border: Border.all(color: medal)),
              child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: medal)),
            ),
            const SizedBox(width: 10),
            MemberAvatar(name: submission.userName, size: 36, highlight: rank == 1),
            const SizedBox(width: 10),
            Expanded(
              child: Text(isMe ? '${submission.userName} (you)' : submission.userName,
                  style: quizTextStyle(size: 15, weight: FontWeight.w600, height: 1.3)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+${formatElapsed(submission.submittedAt.difference(start))}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                Text(formatPreciseTime(submission.submittedAt), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
