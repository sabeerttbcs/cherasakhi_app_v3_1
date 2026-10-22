// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/features/quiz/domain/entities/quiz_report_models.dart';

void main() {
  test('missing or non-HTTPS photo uses a safe initials fallback', () {
    expect(championInitials('Majida Sabeer'), 'MS');
    expect(championInitials('Amina'), 'AM');
    expect(championInitials(''), 'CS');
    expect(isConsentPhotoUrl('https://example.com/majida.jpg'), isTrue);
    expect(isConsentPhotoUrl('http://example.com/majida.jpg'), isFalse);
    expect(isConsentPhotoUrl(''), isFalse);
  });

  test('congratulation identity is unique per month and member', () {
    expect(congratulationDocId('2026-01', 'uid-a'), '2026-01_uid-a');
    expect(congratulationDocId('2026-01', 'uid-a'),
        isNot(congratulationDocId('2026-02', 'uid-a')));
    expect(congratulationDocId('2026-01', 'uid-a'),
        isNot(congratulationDocId('2026-01', 'uid-b')));
  });

  test('best accuracy requires minimum participation and keeps ties', () {
    final report = QuizReport(
      period: QuizReportPeriod(
        kind: QuizReportKind.monthly,
        startUtc: DateTime.utc(2026, 1, 1),
        endUtc: DateTime.utc(2026, 2, 1),
      ),
      category: QuizCategoryFilter.all,
      completedQuizCount: 3,
      totalAnswers: 5,
      totalCorrect: 4,
      totalIncorrect: 1,
      leaderboard: [
        QuizLeaderboardEntry(
          rank: 1,
          userId: 'a',
          name: 'Amina',
          available: 3,
          participated: 1,
          correct: 1,
          incorrect: 0,
          dailyWins: 1,
        ),
        QuizLeaderboardEntry(
          rank: 1,
          userId: 'b',
          name: 'Basil',
          available: 3,
          participated: 2,
          correct: 2,
          incorrect: 0,
          dailyWins: 1,
        ),
        QuizLeaderboardEntry(
          rank: 1,
          userId: 'c',
          name: 'Chitra',
          available: 3,
          participated: 2,
          correct: 2,
          incorrect: 0,
          dailyWins: 1,
        ),
      ],
      dailyWinners: [],
      warnings: [],
    );

    expect(report.bestAccuracyCandidates.map((entry) => entry.userId),
        containsAll(<String>['b', 'c']));
    expect(report.bestAccuracyCandidates, hasLength(2));
  });
}
