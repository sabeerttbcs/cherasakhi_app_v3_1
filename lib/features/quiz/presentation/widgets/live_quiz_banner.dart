import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/quiz_models.dart';
import '../providers/quiz_providers.dart';
import '../screens/live_quiz_screen.dart';
import 'quiz_format.dart';

/// Strip above the bottom navigation: shows a quiz that is live now or
/// starting within 30 minutes. Visible to every member on every tab.
class LiveQuizBanner extends ConsumerStatefulWidget {
  const LiveQuizBanner({super.key});

  @override
  ConsumerState<LiveQuizBanner> createState() => _LiveQuizBannerState();
}

class _LiveQuizBannerState extends ConsumerState<LiveQuizBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contest = ref.watch(featuredQuizProvider);
    final now = ref.watch(serverNowProvider).valueOrNull;
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: contest == null || now == null ? const SizedBox(width: double.infinity) : _banner(contest, now),
    );
  }

  Widget _banner(QuizContest c, DateTime now) {
    final live = c.phaseAt(now) == QuizPhase.live;
    final text = live
        ? 'LIVE · ${c.title} · ${formatCountdown(c.endTime.difference(now))} left'
        : 'Quiz at ${formatClock(c.startTime)} · starts in ${formatCountdown(c.startTime.difference(now))}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveQuizScreen(quizId: c.id))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: live
                ? const LinearGradient(colors: [Color(0xFF7A1A4A), Color(0xFF4A0E2E)])
                : AppColors.roseGoldGradient,
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: live ? const Color(0xFFF87171) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: (live ? const Color(0xFFF87171) : Colors.white).withOpacity(0.7 * _pulse.value),
                        blurRadius: 10,
                        spreadRadius: 3 * _pulse.value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: quizTextStyle(size: 13.5, weight: FontWeight.w700, color: Colors.white, height: 1.3)
                      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              Text(live ? 'JOIN' : 'VIEW',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
