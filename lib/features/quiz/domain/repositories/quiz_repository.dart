import '../entities/quiz_models.dart';

/// Thrown when the server refuses a read/write — usually because the time
/// window isn't open yet (question/answer) or has closed (submissions).
class QuizPermissionDenied implements Exception {
  const QuizPermissionDenied([this.message = 'Not allowed at this time']);
  final String message;

  @override
  String toString() => message;
}

abstract interface class QuizRepository {
  Stream<List<QuizContest>> watchContests();
  Stream<QuizContest?> watchContest(String quizId);

  /// Create (id == null) or edit before start. Seals the answer.
  Future<String> scheduleContest({String? quizId, required QuizDraft draft, required String adminUid});
  Future<void> cancelContest(String quizId);
  Future<void> deleteContest(String quizId);

  /// Server-locked until startTime.
  Future<QuizQuestion> fetchQuestion(String quizId);

  /// Server-locked until endTime (admins always).
  Future<QuizSecret> fetchSecret(String quizId);

  Stream<QuizSubmission?> watchMySubmission(String quizId, String uid);
  Future<void> submitAnswer({
    required String quizId,
    required String uid,
    required String userName,
    required String answer,
  });

  /// Readable after endTime (admins always).
  Future<List<QuizSubmission>> fetchSubmissions(String quizId);
  Stream<int> watchSubmissionCount(String quizId);

  /// Fallback when no Cloud Function is deployed: the admin's device records it.
  Future<void> saveResult(String quizId, QuizResult result);
}
