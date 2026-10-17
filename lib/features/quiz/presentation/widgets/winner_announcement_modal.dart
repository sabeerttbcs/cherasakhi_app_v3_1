import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../domain/entities/quiz_models.dart';
import '../../domain/usecases/quiz_evaluation.dart';
import 'quiz_format.dart';

const _deepBerry = Color(0xFF4A0E2E);

/// Full-screen winner announcement with confetti and WhatsApp share.
Future<void> showWinnerAnnouncement(
  BuildContext context, {
  required QuizContest contest,
  required QuizOutcome outcome,
}) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Quiz winner',
    barrierColor: Colors.black.withOpacity(0.8),
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => WinnerAnnouncementModal(contest: contest, outcome: outcome),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: child),
    ),
  );
}

/// WhatsApp-ready announcement text.
String buildWinnerMessage(QuizContest contest, QuizOutcome outcome) {
  final w = outcome.winner;
  final header = '🏆 *${AppConstants.appName} Live Quiz — Result*\n*${contest.title}*\n\n';
  if (w == null) {
    return '$header'
        'No correct answers this time 🙏\n'
        '✅ Correct answer: *${outcome.correctAnswer}*\n'
        '👥 ${outcome.totalSubmissions} entries\n\n'
        'See you in the next quiz! 🌸';
  }
  return '$header'
      '🥇 Winner (Fastest Finger First): *${w.userName}*\n'
      '✅ Correct answer: *${outcome.correctAnswer}*\n'
      '⏱️ Submitted at ${formatPreciseTime(w.submittedAt)} '
      '(${formatElapsed(w.submittedAt.difference(contest.startTime))} after start)\n'
      '👥 ${outcome.correctCount} correct out of ${outcome.totalSubmissions} entries\n\n'
      'Congratulations! 🎉🌸';
}

class WinnerAnnouncementModal extends StatefulWidget {
  const WinnerAnnouncementModal({super.key, required this.contest, required this.outcome});

  final QuizContest contest;
  final QuizOutcome outcome;

  @override
  State<WinnerAnnouncementModal> createState() => _WinnerAnnouncementModalState();
}

class _WinnerAnnouncementModalState extends State<WinnerAnnouncementModal> {
  final _burst = ConfettiController(duration: const Duration(seconds: 2));
  final _rain = ConfettiController(duration: const Duration(seconds: 5));

  static const _confetti = [
    AppColors.roseGoldLight,
    AppColors.roseGoldPale,
    AppColors.blossom,
    AppColors.lavender,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.outcome.winner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _burst.play();
        _rain.play();
      });
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    _rain.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final ok = await WhatsAppLauncher.send(message: buildWinnerMessage(widget.contest, widget.outcome));
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('WhatsApp is not available')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.outcome.winner;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _rain,
              blastDirection: pi / 2,
              emissionFrequency: 0.07,
              numberOfParticles: 9,
              maxBlastForce: 9,
              minBlastForce: 3,
              gravity: 0.2,
              colors: _confetti,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _card(context, w),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GoldButton(label: 'WHATSAPP', icon: Icons.share_rounded, expand: true, onPressed: _share),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _burst,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 28,
              maxBlastForce: 42,
              minBlastForce: 14,
              gravity: 0.18,
              colors: _confetti,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, QuizSubmission? w) {
    final o = widget.outcome;
    final c = widget.contest;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: AppColors.roseGoldGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppColors.roseGoldLight.withOpacity(0.45), blurRadius: 40)],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: const LinearGradient(
            colors: [Color(0xFF7A1A4A), _deepBerry, Color(0xFF2A0619)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✦  LIVE QUIZ RESULT  ✦',
              style: GoogleFonts.poppins(
                color: AppColors.roseGoldPale,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(c.title,
                textAlign: TextAlign.center,
                style: quizTextStyle(size: 15, weight: FontWeight.w600, color: Colors.white70)),
            const SizedBox(height: 16),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.roseGoldLight.withOpacity(w == null ? 0.15 : 0.5),
                  AppColors.roseGoldLight.withOpacity(0),
                ]),
              ),
              child: Icon(
                w == null ? Icons.sentiment_neutral_rounded : Icons.emoji_events_rounded,
                size: 70,
                color: AppColors.roseGoldPale,
              ),
            ),
            const SizedBox(height: 8),
            if (w != null) ...[
              Text('Fastest Finger First', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                w.userName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: quizTextStyle(size: 28, weight: FontWeight.w800, color: Colors.white, height: 1.3),
              ),
            ] else
              Text('No correct answers this time',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            _row(Icons.check_circle_rounded, 'Correct answer', o.correctAnswer),
            if (w != null) ...[
              _row(Icons.schedule_rounded, 'Submitted at', formatPreciseTime(w.submittedAt)),
              _row(Icons.bolt_rounded, 'Speed', '${formatElapsed(w.submittedAt.difference(c.startTime))} after start'),
            ],
            _row(Icons.groups_rounded, 'Entries', '${o.correctCount} correct of ${o.totalSubmissions}'),
            if (o.sealVerified == true) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF6EE7B7)),
                  const SizedBox(width: 6),
                  Text('Answer verified: sealed before the quiz started',
                      style: GoogleFonts.poppins(color: const Color(0xFF6EE7B7), fontSize: 11.5)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.roseGoldPale.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.roseGoldLight),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: quizTextStyle(size: 14, weight: FontWeight.w700, color: Colors.white, height: 1.35),
              ),
            ),
          ],
        ),
      );
}
