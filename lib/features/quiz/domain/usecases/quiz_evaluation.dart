import '../entities/quiz_models.dart';
import 'answer_tools.dart';

/// Fastest-finger ordering: earliest server timestamp first; userId breaks
/// an exact tie so every device computes the same winner.
int fastestFirst(QuizSubmission a, QuizSubmission b) {
  final byTime = a.submittedAtMicros.compareTo(b.submittedAtMicros);
  return byTime != 0 ? byTime : a.userId.compareTo(b.userId);
}

class QuizOutcome {
  const QuizOutcome({
    required this.correctAnswer,
    required this.fastestCorrect,
    required this.correctIds,
    required this.totalSubmissions,
    this.sealVerified,
  });

  final String correctAnswer;

  /// All correct submissions, fastest first. `[0]` is the winner.
  final List<QuizSubmission> fastestCorrect;
  final Set<String> correctIds;
  final int totalSubmissions;

  /// null = could not check (e.g. built from the stored result only).
  final bool? sealVerified;

  QuizSubmission? get winner => fastestCorrect.isEmpty ? null : fastestCorrect.first;
  int get correctCount => fastestCorrect.length;

  /// 1-based rank among correct answers, or null.
  int? rankOf(String userId) {
    final i = fastestCorrect.indexWhere((s) => s.userId == userId);
    return i < 0 ? null : i + 1;
  }

  QuizResult toResult({required String evaluatedBy}) => QuizResult(
        correctAnswer: correctAnswer,
        correctCount: correctCount,
        totalSubmissions: totalSubmissions,
        winnerId: winner?.userId,
        winnerName: winner?.userName,
        winnerAnswer: winner?.submittedAnswer,
        winnerSubmittedAtMicros: winner?.submittedAtMicros,
        evaluatedBy: evaluatedBy,
      );

  QuizOutcome withSeal(bool? verified) => QuizOutcome(
        correctAnswer: correctAnswer,
        fastestCorrect: fastestCorrect,
        correctIds: correctIds,
        totalSubmissions: totalSubmissions,
        sealVerified: verified,
      );
}

/// Automated timeout evaluation (runs identically on every device and in the
/// Cloud Function):
///   1. keep only submissions inside [startTime, endTime)
///   2. keep only correct answers
///   3. winner = earliest server timestamp
QuizOutcome evaluateQuiz({
  required QuizContest contest,
  required QuizSecret secret,
  required List<QuizSubmission> submissions,
}) {
  final start = contest.startTime.microsecondsSinceEpoch;
  final end = contest.endTime.microsecondsSinceEpoch;
  final valid = submissions
      .where((s) => !s.pending && s.submittedAtMicros >= start && s.submittedAtMicros < end)
      .toList(growable: false);
  final correct = valid.where((s) => isCorrectAnswer(s.submittedAnswer, secret)).toList()..sort(fastestFirst);
  return QuizOutcome(
    correctAnswer: secret.answer,
    fastestCorrect: correct,
    correctIds: {for (final s in correct) s.userId},
    totalSubmissions: valid.length,
    sealVerified: verifySeal(contest, secret),
  );
}

/// Countdown colour state for the live timer.
enum TimerTone { calm, warning, critical }

/// > 50 % left → calm (teal); 20–50 % → warning (amber);
/// final crunch → critical (crimson). The crunch starts at 20 % left, or at
/// 5 minutes left for long quizzes — capped at a third of the quiz so short
/// quizzes don't turn red almost immediately.
TimerTone timerToneFor(Duration remaining, Duration total) {
  if (total <= Duration.zero) return TimerTone.critical;
  final fraction = remaining.inMilliseconds / total.inMilliseconds;
  final fiveMinOrThird = total.inMilliseconds / 3 < const Duration(minutes: 5).inMilliseconds
      ? Duration(milliseconds: total.inMilliseconds ~/ 3)
      : const Duration(minutes: 5);
  if (fraction < 0.2 || remaining < fiveMinOrThird) return TimerTone.critical;
  if (fraction <= 0.5) return TimerTone.warning;
  return TimerTone.calm;
}
