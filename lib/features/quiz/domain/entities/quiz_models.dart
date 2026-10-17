import 'dart:typed_data';

/// Stored lifecycle flag. Timing (scheduled → live → ended) is derived from
/// `startTime` / `endTime` against server time — see [QuizContest.phaseAt].
enum QuizStatus { scheduled, cancelled, completed }

/// What the contest looks like *right now*.
enum QuizPhase { cancelled, scheduled, live, ended }

/// Multiple-choice options, or a typed answer.
enum AnswerMode { options, text }

/// Public contest document: `quizzes/{quizId}`.
/// Contains NO question text and NO answer — only the sealed answer hash.
class QuizContest {
  const QuizContest({
    required this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.encryptedAnswer,
    required this.answerMode,
    required this.status,
    this.optionCount = 0,
    this.hasImage = false,
    this.createdBy,
    this.createdAt,
    this.result,
  });

  final String id;
  final String title;
  final String category;
  final DateTime startTime;
  final DateTime endTime;

  /// `sha256:<hex>` of `salt|normalisedAnswer`. The salt and answer stay in a
  /// server-locked document until [endTime]; this commitment lets every member
  /// verify afterwards that the answer was not changed during the contest.
  final String encryptedAnswer;
  final AnswerMode answerMode;
  final QuizStatus status;
  final int optionCount;
  final bool hasImage;
  final String? createdBy;
  final DateTime? createdAt;

  /// Written after the end by the Cloud Function (or the admin's device).
  final QuizResult? result;

  Duration get duration => endTime.difference(startTime);

  QuizPhase phaseAt(DateTime now) {
    if (status == QuizStatus.cancelled) return QuizPhase.cancelled;
    if (now.isBefore(startTime)) return QuizPhase.scheduled;
    if (now.isBefore(endTime)) return QuizPhase.live;
    return QuizPhase.ended;
  }
}

/// `quizzes/{id}/content/question` — readable from [QuizContest.startTime].
class QuizQuestion {
  const QuizQuestion({required this.text, this.options = const [], this.imageUrl});

  final String text;
  final List<String> options;
  final String? imageUrl;

  AnswerMode get mode => options.isEmpty ? AnswerMode.text : AnswerMode.options;
}

/// `quizzes/{id}/secret/answer` — readable from [QuizContest.endTime] (admins always).
class QuizSecret {
  const QuizSecret({required this.answer, required this.salt, this.acceptedAnswers = const []});

  /// Canonical correct answer (shown on the winner card).
  final String answer;

  /// Extra spellings that also count as correct (typed answers).
  final List<String> acceptedAnswers;
  final String salt;

  List<String> get allAccepted => [answer, ...acceptedAnswers];
}

/// `quizzes/{id}/submissions/{uid}` — one per member, create-only.
class QuizSubmission {
  const QuizSubmission({
    required this.userId,
    required this.userName,
    required this.submittedAnswer,
    required this.submittedAtMicros,
    this.pending = false,
  });

  final String userId;
  final String userName;
  final String submittedAnswer;

  /// Server timestamp with microsecond precision (Firestore stores
  /// nanoseconds). 0 while the write is still pending.
  final int submittedAtMicros;

  /// True until the server has confirmed (and time-stamped) the submission.
  final bool pending;

  DateTime get submittedAt => DateTime.fromMicrosecondsSinceEpoch(submittedAtMicros);
}

/// Final, announced result: `quizzes/{id}.result`.
class QuizResult {
  const QuizResult({
    required this.correctAnswer,
    required this.correctCount,
    required this.totalSubmissions,
    this.winnerId,
    this.winnerName,
    this.winnerAnswer,
    this.winnerSubmittedAtMicros,
    this.evaluatedBy,
  });

  final String correctAnswer;
  final int correctCount;
  final int totalSubmissions;
  final String? winnerId;
  final String? winnerName;
  final String? winnerAnswer;
  final int? winnerSubmittedAtMicros;
  final String? evaluatedBy; // 'function' | 'admin'

  bool get hasWinner => winnerId != null;
  DateTime? get winnerSubmittedAt =>
      winnerSubmittedAtMicros == null ? null : DateTime.fromMicrosecondsSinceEpoch(winnerSubmittedAtMicros!);
}

/// What the admin fills in on the scheduler screen.
class QuizDraft {
  const QuizDraft({
    required this.title,
    required this.category,
    required this.questionText,
    required this.options,
    required this.answer,
    required this.acceptedAnswers,
    required this.startTime,
    required this.endTime,
    this.newImageBytes,
    this.existingImageUrl,
  });

  final String title;
  final String category;
  final String questionText;

  /// Empty → typed-answer contest.
  final List<String> options;
  final String answer;
  final List<String> acceptedAnswers;
  final DateTime startTime;
  final DateTime endTime;
  final Uint8List? newImageBytes;
  final String? existingImageUrl;

  AnswerMode get mode => options.isEmpty ? AnswerMode.text : AnswerMode.options;
}
