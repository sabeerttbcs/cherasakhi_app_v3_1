import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/async_combine.dart';
import '../../../../core/utils/month_key.dart';
import '../../data/firestore_kuri_repository.dart';
import '../../domain/entities/claim.dart';
import '../../domain/entities/kuri_cycle.dart';
import '../../domain/entities/ledger_summary.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/kuri_repository.dart';

typedef MonthRef = ({String cycleId, String monthKey});

final kuriRepositoryProvider = Provider<KuriRepository>(
  (ref) => FirestoreKuriRepository(ref.watch(firestoreProvider)),
);

final membersProvider = StreamProvider<List<Member>>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(kuriRepositoryProvider).watchMembers();
});

final activeCycleProvider = StreamProvider<KuriCycle?>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(kuriRepositoryProvider).watchActiveCycle();
});

/// Month the user picked; [effectiveMonthProvider] clamps it into the cycle.
final selectedMonthProvider = StateProvider<String>((ref) => MonthKey.current());

final effectiveMonthProvider = Provider<String>((ref) {
  final selected = ref.watch(selectedMonthProvider);
  final cycle = ref.watch(activeCycleProvider).valueOrNull;
  return cycle == null ? selected : cycle.clamp(selected);
});

final paymentsProvider = StreamProvider.family<Map<String, Payment>, MonthRef>((ref, key) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(kuriRepositoryProvider).watchPayments(key.cycleId, key.monthKey);
});

final claimsProvider = StreamProvider.family<List<Claim>, String>((ref, cycleId) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(kuriRepositoryProvider).watchClaims(cycleId);
});

final ledgerSummaryProvider = Provider.family<AsyncValue<LedgerSummary>, MonthRef>((ref, key) {
  final members = ref.watch(membersProvider);
  final payments = ref.watch(paymentsProvider(key));
  final cycle = ref.watch(activeCycleProvider);
  return combineAsync([members, payments, cycle], () {
    return LedgerSummary.compute(
      members: members.requireValue,
      payments: payments.requireValue,
      installment: cycle.requireValue?.monthlyInstallment ?? 0,
    );
  });
});
