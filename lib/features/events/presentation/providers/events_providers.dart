import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/async_combine.dart';
import '../../data/firestore_events_repository.dart';
import '../../domain/entities/event_models.dart';
import '../../domain/repositories/events_repository.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => FirestoreEventsRepository(ref.watch(firestoreProvider)),
);

final eventsProvider = StreamProvider<List<EventFund>>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventsRepositoryProvider).watchEvents();
});

final contributionsProvider = StreamProvider.family<List<Contribution>, String>((ref, id) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventsRepositoryProvider).watchContributions(id);
});

final expensesProvider = StreamProvider.family<List<EventExpense>, String>((ref, id) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventsRepositoryProvider).watchExpenses(id);
});

final transfersProvider = StreamProvider.family<List<CashTransfer>, String>((ref, id) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventsRepositoryProvider).watchTransfers(id);
});

final eventLedgerProvider = Provider.family<AsyncValue<EventLedger>, String>((ref, id) {
  final c = ref.watch(contributionsProvider(id));
  final e = ref.watch(expensesProvider(id));
  final t = ref.watch(transfersProvider(id));
  return combineAsync([c, e, t], () {
    return EventLedger.compute(
      contributions: c.requireValue,
      expenses: e.requireValue,
      transfers: t.requireValue,
    );
  });
});
