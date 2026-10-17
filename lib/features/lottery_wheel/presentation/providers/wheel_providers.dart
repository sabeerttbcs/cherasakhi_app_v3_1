import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/async_combine.dart';
import '../../../kuri/domain/entities/kuri_cycle.dart';
import '../../../kuri/presentation/providers/kuri_providers.dart';
import '../../data/firestore_draw_repository.dart';
import '../../domain/entities/draw_record.dart';
import '../../domain/repositories/draw_repository.dart';
import '../../domain/usecases/eligibility.dart';

final drawRepositoryProvider = Provider<DrawRepository>(
  (ref) => FirestoreDrawRepository(ref.watch(firestoreProvider)),
);

final drawsProvider = StreamProvider.family<List<DrawRecord>, String>((ref, cycleId) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(drawRepositoryProvider).watchDraws(cycleId);
});

class WheelData {
  const WheelData({
    required this.cycle,
    required this.monthKey,
    required this.eligibility,
    required this.monthDraw,
    required this.draws,
    required this.potAmount,
  });

  final KuriCycle cycle;
  final String monthKey;
  final EligibilityResult eligibility;
  final DrawRecord? monthDraw;
  final List<DrawRecord> draws;
  final double potAmount;
}

/// Everything the Pamparam screen needs, kept live from Firestore.
final wheelDataProvider = Provider<AsyncValue<WheelData?>>((ref) {
  final cycleAsync = ref.watch(activeCycleProvider);
  if (cycleAsync.hasError) {
    return AsyncError(cycleAsync.error!, cycleAsync.stackTrace ?? StackTrace.current);
  }
  if (!cycleAsync.hasValue) return const AsyncLoading();
  final cycle = cycleAsync.requireValue;
  if (cycle == null) return const AsyncData(null);

  final month = ref.watch(effectiveMonthProvider);
  final members = ref.watch(membersProvider);
  final payments = ref.watch(paymentsProvider((cycleId: cycle.id, monthKey: month)));
  final claims = ref.watch(claimsProvider(cycle.id));
  final draws = ref.watch(drawsProvider(cycle.id));

  return combineAsync<WheelData?>([members, payments, claims, draws], () {
    final eligibility = evaluateEligibility(
      members: members.requireValue,
      payments: payments.requireValue,
      claimedMemberIds: {for (final c in claims.requireValue) c.memberId},
    );
    DrawRecord? monthDraw;
    for (final d in draws.requireValue) {
      if (d.monthKey == month) monthDraw = d;
    }
    final activeCount = members.requireValue.where((m) => m.isActive).length;
    return WheelData(
      cycle: cycle,
      monthKey: month,
      eligibility: eligibility,
      monthDraw: monthDraw,
      draws: draws.requireValue,
      potAmount: cycle.monthlyInstallment * activeCount,
    );
  });
});
