import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/month_key.dart';
import '../../auth/presentation/guards/kuri_guard.dart';
import '../../kuri/presentation/providers/kuri_providers.dart';
import '../../lottery_wheel/domain/entities/draw_record.dart';
import '../../lottery_wheel/presentation/providers/wheel_providers.dart';
import '../../quiz/domain/entities/quiz_models.dart';
import '../../quiz/presentation/providers/quiz_providers.dart';
import '../../quiz/presentation/widgets/quiz_format.dart';

/// Wrap the HomeShell body with this. While the app is open it watches
/// Firestore and fires a notification + chime when:
///   • a Pamparam (Kuri) winner is drawn       → Kuri cohort only
///   • a scheduled live quiz starts            → everyone
///   • a live quiz result is announced         → everyone
/// Existing items at start-up never alert — only new ones.
/// The device that performed the action is skipped (it already celebrates).
class AppAlertsListener extends ConsumerStatefulWidget {
  const AppAlertsListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppAlertsListener> createState() => _AppAlertsListenerState();
}

class _AppAlertsListenerState extends ConsumerState<AppAlertsListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerDevice());
  }

  Future<void> _registerDevice() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final service = NotificationService.instance;
    // Mobile: ask straight away. Web: only re-register silently if the user
    // already allowed it — the first prompt must come from a button tap.
    if (!kIsWeb || service.webPermissionGranted) {
      await service.requestPermissionAndRegister(uid: uid, db: ref.read(firestoreProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUidProvider);
    // Kuri data is private to the cohort: never subscribe for other members.
    final kuri = ref.watch(canAccessKuriProvider);
    final cycle = kuri ? ref.watch(activeCycleProvider).valueOrNull : null;

    if (cycle != null) {
      ref.listen<AsyncValue<List<DrawRecord>>>(drawsProvider(cycle.id), (prev, next) {
        final before = prev?.valueOrNull;
        final after = next.valueOrNull;
        if (before == null || after == null) return; // first load → no alerts
        final known = {for (final d in before) d.monthKey};
        for (final d in after) {
          if (known.contains(d.monthKey) || d.drawnBy == myUid) continue;
          NotificationService.instance.alert(
            kind: AlertKind.winner,
            title: '🏆 പമ്പരം വിജയി! (Pamparam winner)',
            body: '${d.winnerName} won the ${MonthKey.label(d.monthKey)} Kuri — ${formatMoney(d.amount)}',
            dedupeKey: '${cycle.id}/${d.monthKey}',
          );
        }
      });
    }

    // Quiz start: fire when server time crosses a contest's startTime.
    ref.listen<AsyncValue<DateTime>>(serverNowProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final now = next.valueOrNull;
      if (before == null || now == null) return;
      final contests = ref.read(quizContestsProvider).valueOrNull ?? const <QuizContest>[];
      for (final c in contests) {
        if (c.status != QuizStatus.scheduled || c.createdBy == myUid) continue;
        if (before.isBefore(c.startTime) && !now.isBefore(c.startTime)) {
          NotificationService.instance.alert(
            kind: AlertKind.quizLive,
            title: '📝 ലൈവ് ക്വിസ് ആരംഭിച്ചു! (Live quiz started)',
            body: '${c.title} — answer before ${formatClock(c.endTime)}',
            dedupeKey: 'start:${c.id}',
          );
        }
      }
    });

    // Quiz result announced (Cloud Function or admin device wrote `result`).
    ref.listen<AsyncValue<List<QuizContest>>>(quizContestsProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null) return;
      final hadResult = {for (final c in before) if (c.result != null) c.id};
      for (final c in after) {
        final r = c.result;
        if (r == null || hadResult.contains(c.id)) continue;
        NotificationService.instance.alert(
          kind: AlertKind.winner,
          title: '🏆 ക്വിസ് വിജയി! (Quiz winner)',
          body: r.hasWinner
              ? '${r.winnerName} won “${c.title}” — answer: ${r.correctAnswer}'
              : 'No correct answers in “${c.title}”. Answer: ${r.correctAnswer}',
          dedupeKey: 'result:${c.id}',
        );
      }
    });

    return widget.child;
  }
}

/// Optional profile-menu action for the web/PWA, where the first permission
/// prompt has to come from a tap.
Future<void> enableAlertsFromTap(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  final ok = await NotificationService.instance
      .requestPermissionAndRegister(uid: uid, db: ref.read(firestoreProvider));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ok
        ? 'അറിയിപ്പുകൾ ഓണാണ് (Alerts enabled)'
        : 'Notifications are blocked — allow them in browser / phone settings'),
  ));
}
