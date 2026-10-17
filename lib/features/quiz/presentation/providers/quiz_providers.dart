import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/firestore_quiz_repository.dart';
import '../../data/server_clock.dart';
import '../../domain/entities/quiz_models.dart';
import '../../domain/repositories/quiz_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => FirestoreQuizRepository(ref.watch(firestoreProvider)),
);

/// Synced once per sign-in; every quiz countdown uses it.
final serverClockProvider = FutureProvider<ServerClock>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return ServerClock.zero;
  return syncServerClock(ref.watch(firestoreProvider), uid);
});

/// Server-corrected "now", ticking every second (cards, banner).
final serverNowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final clock = await ref.watch(serverClockProvider.future);
  yield clock.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => clock.now());
});

/// All contests, newest start first. Open to every registered member.
final quizContestsProvider = StreamProvider<List<QuizContest>>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(quizRepositoryProvider).watchContests();
});

/// The contest to feature on the home banner: live now, else the next one
/// starting within 30 minutes.
final featuredQuizProvider = Provider.autoDispose<QuizContest?>((ref) {
  final list = ref.watch(quizContestsProvider).valueOrNull ?? const <QuizContest>[];
  final now = ref.watch(serverNowProvider).valueOrNull;
  if (now == null) return null;
  QuizContest? soon;
  for (final c in list) {
    final phase = c.phaseAt(now);
    if (phase == QuizPhase.live) return c;
    if (phase == QuizPhase.scheduled && c.startTime.difference(now) <= const Duration(minutes: 30)) {
      if (soon == null || c.startTime.isBefore(soon.startTime)) soon = c;
    }
  }
  return soon;
});
