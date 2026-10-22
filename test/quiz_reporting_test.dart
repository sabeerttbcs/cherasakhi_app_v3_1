import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/features/quiz/domain/entities/quiz_models.dart';
import 'package:kuri_collective/features/quiz/domain/entities/quiz_report_models.dart';
import 'package:kuri_collective/features/quiz/domain/usecases/answer_tools.dart';
import 'package:kuri_collective/features/quiz/domain/usecases/quiz_reporting.dart';

QuizContest _contest(int index, {String category = 'General Knowledge'}) {
  final start = DateTime.utc(2026, 1, 5 + index, 10);
  return QuizContest(
    id: 'quiz-$index',
    title: 'Quiz $index',
    category: category,
    startTime: start,
    endTime: start.add(const Duration(minutes: 10)),
    encryptedAnswer: sealAnswer('yes', 'salt-$index'),
    answerMode: AnswerMode.text,
    status: QuizStatus.completed,
  );
}

QuizSubmission _submission(
        String uid, String name, String answer, DateTime at) =>
    QuizSubmission(
      userId: uid,
      userName: name,
      submittedAnswer: answer,
      submittedAtMicros: at.microsecondsSinceEpoch,
    );

void main() {
  test('period boundaries use Asia/Kolkata Monday and calendar month', () {
    final now = DateTime.utc(2026, 1, 7, 12);
    final week = QuizReportPeriod.current(QuizReportKind.weekly, nowUtc: now);
    final month = QuizReportPeriod.current(QuizReportKind.monthly, nowUtc: now);

    expect(week.startIndia.weekday, DateTime.monday);
    expect(week.startIndia.day, 5);
    expect(month.startIndia.day, 1);
    expect(month.endIndia.month, 2);
  });

  test('aggregates participation, wrong answers, and fastest daily wins', () {
    final contest = _contest(0);
    final submissions = [
      _submission('a', 'Amina', 'yes',
          contest.startTime.add(const Duration(seconds: 2))),
      _submission('b', 'Basil', 'no',
          contest.startTime.add(const Duration(seconds: 1))),
    ];
    final report = aggregateQuizReport(
      period: QuizReportPeriod.current(QuizReportKind.daily,
          nowUtc: DateTime.utc(2026, 1, 6)),
      category: QuizCategoryFilter.all,
      quizzes: [
        CompletedQuizReportInput(
          contest: contest,
          secret: const QuizSecret(answer: 'yes', salt: 'salt-0'),
          submissions: submissions,
        ),
      ],
    );

    expect(report.completedQuizCount, 1);
    expect(report.totalAnswers, 2);
    expect(report.totalCorrect, 1);
    expect(report.totalIncorrect, 1);
    expect(report.dailyWinners.single.userId, 'a');
    expect(report.leaderboard.first.name, 'Amina');
    expect(report.leaderboard.last.incorrect, 1);
  });

  test(
      'category filters and ties remain transparent across more than 50 quizzes',
      () {
    final quizzes = [
      for (var i = 0; i < 60; i++)
        CompletedQuizReportInput(
          contest: _contest(i,
              category: i.isEven ? 'Islamic Quiz' : 'General Knowledge Quiz'),
          secret: QuizSecret(answer: 'yes', salt: 'salt-$i'),
          submissions: i.isEven
              ? [
                  _submission('a', 'Amina', 'yes',
                      _contest(i).startTime.add(const Duration(seconds: 1))),
                  _submission('b', 'Basil', 'yes',
                      _contest(i).startTime.add(const Duration(seconds: 2))),
                ]
              : [
                  _submission('b', 'Basil', 'yes',
                      _contest(i).startTime.add(const Duration(seconds: 1))),
                  _submission('a', 'Amina', 'yes',
                      _contest(i).startTime.add(const Duration(seconds: 2))),
                ],
        ),
    ];
    final report = aggregateQuizReport(
      period: QuizReportPeriod.current(QuizReportKind.monthly),
      category: QuizCategoryFilter.all,
      quizzes: quizzes,
    );

    expect(report.completedQuizCount, 60);
    expect(report.leaderboard.first.rank, 1);
    expect(report.leaderboard[1].rank, 1);
    expect(categoryMatches('ഇസ്ലാമിക് ക്വിസ്', QuizCategoryFilter.islamic),
        isTrue);
    expect(
        categoryMatches('പൊതു വിജ്ഞാനം', QuizCategoryFilter.general), isTrue);
  });
}
