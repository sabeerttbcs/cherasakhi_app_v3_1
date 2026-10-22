import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/entities/quiz_report_models.dart';
import '../domain/entities/quiz_models.dart';
import '../domain/repositories/quiz_repository.dart';
import '../domain/usecases/quiz_reporting.dart';

class QuizPrizeSelection {
  const QuizPrizeSelection({
    required this.monthKey,
    required this.criterion,
    required this.recipientUid,
    required this.recipientName,
    this.photoUrl = '',
    this.confirmedAt,
  });

  final String monthKey;
  final PrizeCriterion criterion;
  final String recipientUid;
  final String recipientName;
  final String photoUrl;
  final DateTime? confirmedAt;
}

class QuizReportRepository {
  QuizReportRepository(this._db, this._quizzes);

  final FirebaseFirestore _db;
  final QuizRepository _quizzes;

  CollectionReference<Json> get _prizes => _db.collection('quizPrizes');

  Future<QuizReport> loadReport({
    required QuizReportPeriod period,
    required QuizCategoryFilter category,
    bool includeAllMembers = false,
  }) async {
    final all = await _quizzes.fetchContestsInRange(
      start: period.startUtc,
      end: period.endUtc,
    );
    final now = DateTime.now().toUtc();
    final warnings = <String>[];
    final usable = <CompletedQuizReportInput>[];

    for (final contest in all
        .where((contest) => categoryMatches(contest.category, category))) {
      final ended = contest.endTime.toUtc().isBefore(now);
      if (!ended) continue;
      if (contest.status != QuizStatus.completed || contest.result == null) {
        warnings.add('Incomplete result: ${contest.title} was not finalized.');
        continue;
      }
      try {
        final secret = await _quizzes.fetchSecret(contest.id);
        final submissions = await _quizzes.fetchSubmissions(contest.id);
        final input = CompletedQuizReportInput(
          contest: contest,
          secret: secret,
          submissions: submissions,
        );
        final evaluated = aggregateQuizReport(
          period: period,
          category: category,
          quizzes: [input],
        );
        final result = contest.result!;
        final evaluatedWinner = evaluated.dailyWinners.firstOrNull?.userId;
        if (result.correctCount != evaluated.totalCorrect ||
            result.totalSubmissions != evaluated.totalAnswers ||
            result.winnerId != evaluatedWinner) {
          warnings.add(
              'Unavailable result: ${contest.title} does not match its stored evaluation.');
          continue;
        }
        usable.add(input);
      } catch (_) {
        warnings.add(
            'Unavailable result: ${contest.title} could not be read completely.');
      }
    }

    Map<String, String> memberNames = const {};
    if (includeAllMembers) {
      final users = await _db
          .collection('users')
          .get(const GetOptions(source: Source.server));
      memberNames = {
        for (final doc in users.docs)
          doc.id: asString(doc.data()['name'], 'Member'),
      };
    }

    return aggregateQuizReport(
      period: period,
      category: category,
      quizzes: usable,
      warnings: warnings,
      memberNames: memberNames,
    );
  }

  Future<QuizPrizeSelection?> fetchPrize(String monthKey) async {
    final snapshot = await _prizes
        .doc(monthKey)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final criterion = PrizeCriterion.values.firstWhere(
      (value) => value.firestoreValue == data['criterion'],
      orElse: () => PrizeCriterion.mostCorrect,
    );
    return QuizPrizeSelection(
      monthKey: asString(data['monthKey'], monthKey),
      criterion: criterion,
      recipientUid: asString(data['recipientUid']),
      recipientName: asString(data['recipientName'], 'Member'),
      photoUrl: asString(data['photoUrl']),
      confirmedAt: tsToDate(data['confirmedAt']),
    );
  }

  Future<void> confirmPrize({
    required QuizReportPeriod period,
    required PrizeCriterion criterion,
    required QuizLeaderboardEntry recipient,
    String photoUrl = '',
  }) =>
      _prizes.doc(period.monthKey).set({
        'monthKey': period.monthKey,
        'criterion': criterion.firestoreValue,
        'recipientUid': recipient.userId,
        'recipientName': recipient.name,
        'photoUrl': photoUrl.trim(),
        'confirmedAt': FieldValue.serverTimestamp(),
      });

  Future<QuizPrizeSelection?> fetchLatestPrize() async {
    final snapshot = await _prizes
        .orderBy('confirmedAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    final criterion = PrizeCriterion.values.firstWhere(
      (value) => value.firestoreValue == data['criterion'],
      orElse: () => PrizeCriterion.mostCorrect,
    );
    return QuizPrizeSelection(
      monthKey: asString(data['monthKey'], snapshot.docs.first.id),
      criterion: criterion,
      recipientUid: asString(data['recipientUid']),
      recipientName: asString(data['recipientName'], 'Member'),
      photoUrl: asString(data['photoUrl']),
      confirmedAt: tsToDate(data['confirmedAt']),
    );
  }

  CollectionReference<Json> get _congratulations =>
      _db.collection('quizPrizeCongratulations');

  Future<int> fetchCongratulationCount(String monthKey) async {
    final snapshot = await _congratulations
        .where('monthKey', isEqualTo: monthKey)
        .get(const GetOptions(source: Source.server));
    return snapshot.size;
  }

  Future<bool> hasCongratulated(
      {required String monthKey, required String uid}) async {
    final snapshot = await _congratulations
        .doc(congratulationDocId(monthKey, uid))
        .get(const GetOptions(source: Source.server));
    return snapshot.exists;
  }

  Future<void> congratulate({required String monthKey, required String uid}) =>
      _congratulations.doc(congratulationDocId(monthKey, uid)).set({
        'monthKey': monthKey,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
