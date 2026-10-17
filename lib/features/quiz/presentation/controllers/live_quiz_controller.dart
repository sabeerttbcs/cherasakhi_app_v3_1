import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/server_clock.dart';
import '../../domain/entities/quiz_models.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../../domain/usecases/answer_tools.dart';
import '../../domain/usecases/quiz_evaluation.dart';
import '../providers/quiz_providers.dart';

const _unset = Object();

@immutable
class LiveQuizState {
  const LiveQuizState({
    this.loading = true,
    this.contest,
    this.phase = QuizPhase.scheduled,
    this.remaining = Duration.zero,
    this.question,
    this.questionUnavailable = false,
    this.mySubmission,
    this.submitting = false,
    this.message,
    this.evaluating = false,
    this.outcome,
    this.submissionCount,
  });

  final bool loading;
  final QuizContest? contest;
  final QuizPhase phase;

  /// Until start (scheduled) or until end (live).
  final Duration remaining;
  final QuizQuestion? question;
  final bool questionUnavailable;
  final QuizSubmission? mySubmission;
  final bool submitting;

  /// One-off info / error text for the UI.
  final String? message;
  final bool evaluating;
  final QuizOutcome? outcome;

  /// Admin only: live number of submissions.
  final int? submissionCount;

  Duration get total => contest?.duration ?? Duration.zero;

  double get fractionRemaining {
    final t = total.inMilliseconds;
    if (t <= 0 || phase != QuizPhase.live) return 0;
    return (remaining.inMilliseconds / t).clamp(0.0, 1.0).toDouble();
  }

  TimerTone get tone => timerToneFor(remaining, total);
  bool get isLocked => phase != QuizPhase.live;
  bool get hasSubmitted => mySubmission != null;

  LiveQuizState copyWith({
    bool? loading,
    Object? contest = _unset,
    QuizPhase? phase,
    Duration? remaining,
    Object? question = _unset,
    bool? questionUnavailable,
    Object? mySubmission = _unset,
    bool? submitting,
    Object? message = _unset,
    bool? evaluating,
    Object? outcome = _unset,
    Object? submissionCount = _unset,
  }) =>
      LiveQuizState(
        loading: loading ?? this.loading,
        contest: identical(contest, _unset) ? this.contest : contest as QuizContest?,
        phase: phase ?? this.phase,
        remaining: remaining ?? this.remaining,
        question: identical(question, _unset) ? this.question : question as QuizQuestion?,
        questionUnavailable: questionUnavailable ?? this.questionUnavailable,
        mySubmission: identical(mySubmission, _unset) ? this.mySubmission : mySubmission as QuizSubmission?,
        submitting: submitting ?? this.submitting,
        message: identical(message, _unset) ? this.message : message as String?,
        evaluating: evaluating ?? this.evaluating,
        outcome: identical(outcome, _unset) ? this.outcome : outcome as QuizOutcome?,
        submissionCount: identical(submissionCount, _unset) ? this.submissionCount : submissionCount as int?,
      );
}

/// Drives one live contest:
///  • server-synced countdown (to start, then to end), 5 ticks/s, state
///    emitted once per second or on phase change
///  • loads the question the moment the window opens
///  • single submission, locked at endTime (also enforced by Firestore rules)
///  • at 00:00: fetches the revealed answer + all submissions, runs the
///    fastest-finger evaluation, verifies the seal; the admin's device saves
///    the result if the Cloud Function hasn't already
class LiveQuizController extends StateNotifier<LiveQuizState> {
  LiveQuizController(this._ref, this.quizId) : super(const LiveQuizState()) {
    _start();
  }

  final Ref _ref;
  final String quizId;

  ServerClock _clock = ServerClock.zero;
  StreamSubscription<QuizContest?>? _contestSub;
  StreamSubscription<QuizSubmission?>? _mySub;
  StreamSubscription<int>? _countSub;
  Timer? _ticker;
  bool _questionRequested = false;
  bool _evaluationStarted = false;

  QuizRepository get _repo => _ref.read(quizRepositoryProvider);
  DateTime get serverNow => _clock.now();

  Future<void> _start() async {
    _clock = await _ref.read(serverClockProvider.future);
    if (!mounted) return;

    _contestSub = _repo.watchContest(quizId).listen(
      (c) {
        if (!mounted) return;
        if (c == null) {
          state = state.copyWith(loading: false, contest: null, message: 'This quiz no longer exists.');
          return;
        }
        state = state.copyWith(loading: false, contest: c);
        _tick();
      },
      onError: (Object e) {
        if (mounted) state = state.copyWith(loading: false, message: 'Could not load quiz: $e');
      },
    );

    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _mySub = _repo.watchMySubmission(quizId, user.uid).listen((s) {
        if (mounted) state = state.copyWith(mySubmission: s);
      }, onError: (_) {});
      if (user.canManageQuiz) {
        _countSub = _repo.watchSubmissionCount(quizId).listen((n) {
          if (mounted) state = state.copyWith(submissionCount: n);
        }, onError: (_) {});
      }
    }

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final c = state.contest;
    if (c == null || !mounted) return;
    final now = serverNow;
    final phase = c.phaseAt(now);
    final remaining = switch (phase) {
      QuizPhase.scheduled => c.startTime.difference(now),
      QuizPhase.live => c.endTime.difference(now),
      _ => Duration.zero,
    };
    if (phase != state.phase || remaining.inSeconds != state.remaining.inSeconds) {
      state = state.copyWith(phase: phase, remaining: remaining);
    }
    if (phase == QuizPhase.live || phase == QuizPhase.ended) _ensureQuestion();
    if (phase == QuizPhase.ended) _ensureEvaluation();
  }

  /// Retries briefly: if this phone's clock is slightly ahead of the server,
  /// the rules may still say "not yet".
  Future<T?> _retryWhileLocked<T>(Future<T> Function() op, {int attempts = 10}) async {
    for (var i = 0; i < attempts && mounted; i++) {
      try {
        return await op();
      } on QuizPermissionDenied {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<void> _ensureQuestion() async {
    if (_questionRequested) return;
    _questionRequested = true;
    final q = await _retryWhileLocked(() => _repo.fetchQuestion(quizId));
    if (!mounted) return;
    state = q == null ? state.copyWith(questionUnavailable: true) : state.copyWith(question: q);
  }

  Future<void> _ensureEvaluation() async {
    if (_evaluationStarted) return;
    _evaluationStarted = true;
    final contest = state.contest!;
    state = state.copyWith(evaluating: true);

    final secret = await _retryWhileLocked(() => _repo.fetchSecret(quizId));
    final submissions = secret == null ? null : await _retryWhileLocked(() => _repo.fetchSubmissions(quizId));
    if (!mounted) return;

    if (secret == null || submissions == null) {
      // Offline: fall back to the announced result if there is one.
      final r = state.contest?.result;
      state = state.copyWith(
        evaluating: false,
        outcome: r == null ? null : _outcomeFromStoredResult(r),
        message: r == null ? 'Results will appear when you are back online.' : null,
      );
      return;
    }

    final outcome = evaluateQuiz(contest: contest, secret: secret, submissions: submissions);
    state = state.copyWith(evaluating: false, outcome: outcome);

    // No Cloud Function? The admin's device announces the result.
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null && user.canManageQuiz && state.contest?.result == null) {
      try {
        await _repo.saveResult(quizId, outcome.toResult(evaluatedBy: 'admin'));
      } catch (_) {/* function may have written it first — fine */}
    }
  }

  QuizOutcome _outcomeFromStoredResult(QuizResult r) => QuizOutcome(
        correctAnswer: r.correctAnswer,
        fastestCorrect: [
          if (r.hasWinner)
            QuizSubmission(
              userId: r.winnerId!,
              userName: r.winnerName ?? 'Winner',
              submittedAnswer: r.winnerAnswer ?? r.correctAnswer,
              submittedAtMicros: r.winnerSubmittedAtMicros ?? 0,
            ),
        ],
        correctIds: {if (r.winnerId != null) r.winnerId!},
        totalSubmissions: r.totalSubmissions,
      );

  /// One answer per member. Returns true when the server accepted it.
  Future<bool> submit(String answer) async {
    final contest = state.contest;
    final user = _ref.read(appUserProvider).valueOrNull;
    final text = answer.trim();
    if (contest == null || user == null || text.isEmpty) return false;
    if (!user.canPlayQuiz) {
      state = state.copyWith(message: 'Admins host the quiz and cannot submit answers.');
      return false;
    }
    if (state.isLocked) {
      state = state.copyWith(message: 'Submissions are locked.');
      return false;
    }
    if (state.hasSubmitted || state.submitting) return false;

    state = state.copyWith(submitting: true, message: null);
    try {
      await _repo
          .submitAnswer(quizId: quizId, uid: user.uid, userName: user.name, answer: text)
          .timeout(const Duration(seconds: 15));
      if (mounted) state = state.copyWith(submitting: false);
      return true;
    } on TimeoutException {
      if (mounted) {
        state = state.copyWith(
          submitting: false,
          message: 'Waiting for network… your answer is sent automatically if you reconnect before the end time.',
        );
      }
      return false;
    } on QuizPermissionDenied {
      if (mounted) {
        state = state.copyWith(
          submitting: false,
          message: serverNow.isBefore(contest.endTime)
              ? 'Submission rejected — you may have already answered.'
              : 'Time is up — submissions are locked.',
        );
      }
      return false;
    } catch (e) {
      if (mounted) state = state.copyWith(submitting: false, message: 'Could not submit: $e');
      return false;
    }
  }

  void clearMessage() => state = state.copyWith(message: null);

  /// Normalised check the UI uses to colour "your answer" after the reveal.
  bool isMyAnswerCorrect() {
    final mine = state.mySubmission;
    final outcome = state.outcome;
    if (mine == null || outcome == null) return false;
    return outcome.correctIds.contains(mine.userId) ||
        normalizeAnswer(mine.submittedAnswer) == normalizeAnswer(outcome.correctAnswer);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _contestSub?.cancel();
    _mySub?.cancel();
    _countSub?.cancel();
    super.dispose();
  }
}

final liveQuizControllerProvider =
    StateNotifierProvider.autoDispose.family<LiveQuizController, LiveQuizState, String>(
  (ref, quizId) => LiveQuizController(ref, quizId),
);
