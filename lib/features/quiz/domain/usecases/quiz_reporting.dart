import '../entities/quiz_models.dart';
import '../entities/quiz_report_models.dart';
import 'answer_tools.dart';
import 'quiz_evaluation.dart';

class CompletedQuizReportInput {
  const CompletedQuizReportInput({
    required this.contest,
    required this.secret,
    required this.submissions,
  });

  final QuizContest contest;
  final QuizSecret secret;
  final List<QuizSubmission> submissions;
}

/// Aggregates already-authorized quiz data. It deliberately calls the same
/// answer matching and fastest-correct evaluator used by the daily result UI.
QuizReport aggregateQuizReport({
  required QuizReportPeriod period,
  required QuizCategoryFilter category,
  required List<CompletedQuizReportInput> quizzes,
  List<String> warnings = const [],
  Map<String, String> memberNames = const {},
}) {
  final stats = <String, _MutableStats>{};
  final winners = <QuizDailyWinner>[];
  var totalAnswers = 0;
  var totalCorrect = 0;
  final allWarnings = [...warnings];

  for (final entry in memberNames.entries) {
    stats[entry.key] = _MutableStats(
      name: entry.value.trim().isEmpty ? 'Member' : entry.value.trim(),
    );
  }

  for (final quiz in quizzes) {
    final outcome = evaluateQuiz(
      contest: quiz.contest,
      secret: quiz.secret,
      submissions: quiz.submissions,
    );
    if (outcome.sealVerified != true) {
      allWarnings.add(
          'Unavailable result: ${quiz.contest.title} has an invalid answer seal.');
      continue;
    }
    final valid = quiz.submissions
        .where((submission) =>
            !submission.pending &&
            submission.submittedAtMicros >=
                quiz.contest.startTime.microsecondsSinceEpoch &&
            submission.submittedAtMicros <
                quiz.contest.endTime.microsecondsSinceEpoch)
        .toList(growable: false);
    final correctIds = outcome.correctIds;
    totalAnswers += valid.length;
    totalCorrect += correctIds.length;

    for (final submission in valid) {
      final entry = stats.putIfAbsent(
        submission.userId,
        () => _MutableStats(
            name: submission.userName.trim().isEmpty
                ? 'Member'
                : submission.userName.trim()),
      );
      entry.participated++;
      if (correctIds.contains(submission.userId)) {
        entry.correct++;
      } else {
        entry.incorrect++;
      }
    }

    final winner = outcome.winner;
    if (winner != null) {
      stats
          .putIfAbsent(
            winner.userId,
            () => _MutableStats(
                name: winner.userName.trim().isEmpty
                    ? 'Member'
                    : winner.userName.trim()),
          )
          .dailyWins++;
      winners.add(QuizDailyWinner(
        quizId: quiz.contest.id,
        title: quiz.contest.title,
        date: quiz.contest.startTime,
        userId: winner.userId,
        name: winner.userName,
        category: quiz.contest.category,
      ));
    }
  }

  final sorted = stats.entries.toList()
    ..sort((a, b) {
      final byCorrect = b.value.correct.compareTo(a.value.correct);
      if (byCorrect != 0) return byCorrect;
      final byParticipation =
          b.value.participated.compareTo(a.value.participated);
      if (byParticipation != 0) return byParticipation;
      final byWins = b.value.dailyWins.compareTo(a.value.dailyWins);
      if (byWins != 0) return byWins;
      final byAccuracy = b.value.accuracy.compareTo(a.value.accuracy);
      if (byAccuracy != 0) return byAccuracy;
      return a.key.compareTo(b.key);
    });

  final leaderboard = <QuizLeaderboardEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final item = sorted[i];
    final rank = 1 +
        sorted
            .take(i)
            .where((previous) =>
                previous.value.correct > item.value.correct ||
                (previous.value.correct == item.value.correct &&
                    previous.value.participated > item.value.participated) ||
                (previous.value.correct == item.value.correct &&
                    previous.value.participated == item.value.participated &&
                    previous.value.dailyWins > item.value.dailyWins) ||
                (previous.value.correct == item.value.correct &&
                    previous.value.participated == item.value.participated &&
                    previous.value.dailyWins == item.value.dailyWins &&
                    previous.value.accuracy > item.value.accuracy))
            .length;
    leaderboard.add(QuizLeaderboardEntry(
      rank: rank,
      userId: item.key,
      name: item.value.name,
      available: quizzes.length,
      participated: item.value.participated,
      correct: item.value.correct,
      incorrect: item.value.incorrect,
      dailyWins: item.value.dailyWins,
    ));
  }

  return QuizReport(
    period: period,
    category: category,
    completedQuizCount: quizzes.length,
    totalAnswers: totalAnswers,
    totalCorrect: totalCorrect,
    totalIncorrect: totalAnswers - totalCorrect,
    leaderboard: leaderboard,
    dailyWinners: winners,
    warnings: allWarnings,
  );
}

class _MutableStats {
  _MutableStats({required this.name});

  final String name;
  int participated = 0;
  int correct = 0;
  int incorrect = 0;
  int dailyWins = 0;

  double get accuracy => participated == 0 ? 0 : correct / participated;
}

/// Public helper for tests and report integrity checks.
bool isCorrectReportAnswer(String submitted, QuizSecret secret) =>
    isCorrectAnswer(submitted, secret);
