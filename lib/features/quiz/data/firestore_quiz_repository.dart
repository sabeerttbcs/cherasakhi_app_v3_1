import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/entities/quiz_models.dart';
import '../domain/repositories/quiz_repository.dart';
import '../domain/usecases/answer_tools.dart';

/// Firestore layout
/// ```
/// quizzes/{quizId}                     public: title, times, sealed answer, result
///   content/question                   readable from startTime
///   secret/answer                      readable from endTime (admin always)
///   submissions/{uid}                  create-only, startTime ≤ request.time < endTime
/// ```
class FirestoreQuizRepository implements QuizRepository {
  FirestoreQuizRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _quizzes => _db.collection('quizzes');
  DocumentReference<Json> _content(String id) =>
      _quizzes.doc(id).collection('content').doc('question');
  DocumentReference<Json> _secret(String id) =>
      _quizzes.doc(id).collection('secret').doc('answer');
  CollectionReference<Json> _submissions(String id) =>
      _quizzes.doc(id).collection('submissions');

  static int _micros(Object? v) =>
      v is Timestamp ? v.seconds * 1000000 + v.nanoseconds ~/ 1000 : 0;

  static Never _guard(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      throw const QuizPermissionDenied();
    }
    throw e;
  }

  // ───────────────────────── contests ─────────────────────────

  QuizContest _contestFromDoc(JsonDoc d) {
    final m = d.data() ?? const <String, dynamic>{};
    final r = m['result'];
    return QuizContest(
      id: d.id,
      title: asString(m['title'], 'Live Quiz'),
      category: asString(m['category']),
      startTime:
          tsToDate(m['startTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endTime: tsToDate(m['endTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      encryptedAnswer: asString(m['encryptedAnswer']),
      answerMode:
          m['answerMode'] == 'options' ? AnswerMode.options : AnswerMode.text,
      status:
          QuizStatus.values.asNameMap()[m['status']] ?? QuizStatus.scheduled,
      optionCount: asInt(m['optionCount']),
      createdBy: m['createdBy'] as String?,
      createdAt: tsToDate(m['createdAt']),
      result: r is Map<String, dynamic>
          ? QuizResult(
              correctAnswer: asString(r['correctAnswer']),
              correctCount: asInt(r['correctCount']),
              totalSubmissions: asInt(r['totalSubmissions']),
              winnerId: r['winnerId'] as String?,
              winnerName: r['winnerName'] as String?,
              winnerAnswer: r['winnerAnswer'] as String?,
              winnerSubmittedAtMicros: r['winnerSubmittedAt'] == null
                  ? null
                  : _micros(r['winnerSubmittedAt']),
              evaluatedBy: r['evaluatedBy'] as String?,
            )
          : null,
    );
  }

  @override
  Stream<List<QuizContest>> watchContests() => _quizzes
      .orderBy('startTime', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(_contestFromDoc).toList(growable: false));

  @override
  Future<List<QuizContest>> fetchContestsInRange(
      {required DateTime start, required DateTime end}) async {
    final contests = <QuizContest>[];
    DocumentSnapshot<Json>? cursor;
    while (true) {
      Query<Json> query = _quizzes
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start.toUtc()))
          .where('startTime', isLessThan: Timestamp.fromDate(end.toUtc()))
          .orderBy('startTime')
          .limit(100);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get(const GetOptions(source: Source.server));
      contests.addAll(page.docs.map(_contestFromDoc));
      if (page.docs.length < 100) break;
      cursor = page.docs.last;
    }
    return contests;
  }

  @override
  Stream<QuizContest?> watchContest(String quizId) => _quizzes
      .doc(quizId)
      .snapshots()
      .map((d) => d.exists ? _contestFromDoc(d) : null);

  @override
  Future<String> scheduleContest(
      {String? quizId,
      required QuizDraft draft,
      required String adminUid}) async {
    final ref = quizId == null ? _quizzes.doc() : _quizzes.doc(quizId);

    final salt = generateSalt();
    final options =
        draft.options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    final accepted = draft.acceptedAnswers
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    final batch = _db.batch();
    batch.set(
      ref,
      {
        'title': draft.title.trim(),
        'category': draft.category.trim(),
        'startTime': Timestamp.fromDate(draft.startTime),
        'endTime': Timestamp.fromDate(draft.endTime),
        'encryptedAnswer': sealAnswer(draft.answer, salt),
        'answerMode': options.isEmpty ? 'text' : 'options',
        'optionCount': options.length,
        'status': 'scheduled',
        'createdBy': adminUid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (quizId == null) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_content(ref.id), {
      'text': draft.questionText.trim(),
      'options': options,
    });
    batch.set(_secret(ref.id), {
      'answer': draft.answer.trim(),
      'acceptedAnswers': accepted,
      'salt': salt,
    });
    try {
      await batch.commit();
    } catch (e) {
      _guard(e);
    }
    return ref.id;
  }

  @override
  Future<void> cancelContest(String quizId) => _quizzes.doc(quizId).update(
      {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> deleteContest(String quizId) async {
    final batch = _db.batch()
      ..delete(_content(quizId))
      ..delete(_secret(quizId))
      ..delete(_quizzes.doc(quizId));
    await batch.commit();
  }

  // ───────────────────────── time-locked reads ─────────────────────────

  @override
  Future<QuizQuestion> fetchQuestion(String quizId) async {
    try {
      final d =
          await _content(quizId).get(const GetOptions(source: Source.server));
      final m = d.data() ?? const <String, dynamic>{};
      return QuizQuestion(
        text: asString(m['text']),
        options:
            (m['options'] as List?)?.whereType<String>().toList() ?? const [],
      );
    } catch (e) {
      _guard(e);
    }
  }

  @override
  Future<QuizSecret> fetchSecret(String quizId) async {
    try {
      final d =
          await _secret(quizId).get(const GetOptions(source: Source.server));
      final m = d.data() ?? const <String, dynamic>{};
      return QuizSecret(
        answer: asString(m['answer']),
        acceptedAnswers:
            (m['acceptedAnswers'] as List?)?.whereType<String>().toList() ??
                const [],
        salt: asString(m['salt']),
      );
    } catch (e) {
      _guard(e);
    }
  }

  // ───────────────────────── submissions ─────────────────────────

  QuizSubmission _submissionFromDoc(JsonDoc d) {
    final m = d.data() ?? const <String, dynamic>{};
    return QuizSubmission(
      userId: asString(m['userId'], d.id),
      userName: asString(m['userName'], 'Member'),
      submittedAnswer: asString(m['submittedAnswer']),
      submittedAtMicros: _micros(m['submittedAt']),
      pending: d.metadata.hasPendingWrites || m['submittedAt'] is! Timestamp,
    );
  }

  @override
  Stream<QuizSubmission?> watchMySubmission(String quizId, String uid) =>
      _submissions(quizId)
          .doc(uid)
          .snapshots(includeMetadataChanges: true)
          .map((d) => d.exists ? _submissionFromDoc(d) : null);

  @override
  Future<void> submitAnswer({
    required String quizId,
    required String uid,
    required String userName,
    required String answer,
  }) async {
    try {
      await _submissions(quizId).doc(uid).set({
        'userId': uid,
        'userName': userName,
        'submittedAnswer': answer.trim(),
        'submittedAt':
            FieldValue.serverTimestamp(), // server clock, µs precision
      });
    } catch (e) {
      _guard(e);
    }
  }

  @override
  Future<List<QuizSubmission>> fetchSubmissions(String quizId) async {
    try {
      final s = await _submissions(quizId)
          .get(const GetOptions(source: Source.server));
      return s.docs.map(_submissionFromDoc).toList(growable: false);
    } catch (e) {
      _guard(e);
    }
  }

  @override
  Stream<int> watchSubmissionCount(String quizId) =>
      _submissions(quizId).snapshots().map((s) => s.size);

  @override
  Future<void> saveResult(String quizId, QuizResult r) =>
      _quizzes.doc(quizId).update({
        'status': 'completed',
        'result': {
          'correctAnswer': r.correctAnswer,
          'correctCount': r.correctCount,
          'totalSubmissions': r.totalSubmissions,
          'winnerId': r.winnerId,
          'winnerName': r.winnerName,
          'winnerAnswer': r.winnerAnswer,
          'winnerSubmittedAt': r.winnerSubmittedAtMicros == null
              ? null
              : Timestamp(r.winnerSubmittedAtMicros! ~/ 1000000,
                  (r.winnerSubmittedAtMicros! % 1000000) * 1000),
          'evaluatedBy': r.evaluatedBy ?? 'admin',
          'evaluatedAt': FieldValue.serverTimestamp(),
        },
      });
}
