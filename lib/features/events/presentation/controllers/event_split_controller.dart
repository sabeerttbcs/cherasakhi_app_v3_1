import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/event_split_repository.dart';
import '../../domain/entities/event_models.dart';
import '../../domain/split/split_engine.dart';
import '../../domain/split/trip_participant.dart';
import '../providers/events_providers.dart';
import '../widgets/split_format.dart';

// ───────────────────────────── providers ─────────────────────────────

final eventSplitRepositoryProvider = Provider<EventSplitRepository>(
  (ref) => EventSplitRepository(ref.watch(firestoreProvider)),
);

final eventParticipantsProvider = StreamProvider.family<List<TripParticipant>, String>((ref, eventId) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventSplitRepositoryProvider).watchParticipants(eventId);
});

final eventSplitControllerProvider =
    StateNotifierProvider.autoDispose.family<EventSplitController, EventSplitState, String>(
  (ref, eventId) => EventSplitController(ref, eventId),
);

/// The participant id this signed-in user would have on a trip.
String? participantIdFor(AppUser? user) => user?.memberId ?? user?.communityId;

// ───────────────────────────── state ─────────────────────────────

@immutable
class EventSplitState {
  const EventSplitState({
    this.loading = true,
    this.participants = const [],
    this.expenses = const [],
    this.summary = SplitSummary.empty,
    this.changeNote,
    this.error,
  });

  final bool loading;
  final List<TripParticipant> participants;

  /// Newest first (as streamed).
  final List<EventExpense> expenses;
  final SplitSummary summary;

  /// e.g. "Fathima joined · share ₹1,000 → ₹952.38" — shown briefly.
  final String? changeNote;
  final String? error;

  List<TripParticipant> get activeParticipants => participants.where((p) => p.active).toList(growable: false);

  bool isActiveParticipant(String? id) => id != null && participants.any((p) => p.id == id && p.active);
  bool isListed(String? id) => id != null && participants.any((p) => p.id == id);

  EventSplitState copyWith({
    bool? loading,
    List<TripParticipant>? participants,
    List<EventExpense>? expenses,
    SplitSummary? summary,
    String? changeNote,
    bool clearNote = false,
    String? error,
  }) =>
      EventSplitState(
        loading: loading ?? this.loading,
        participants: participants ?? this.participants,
        expenses: expenses ?? this.expenses,
        summary: summary ?? this.summary,
        changeNote: clearNote ? null : (changeNote ?? this.changeNote),
        error: error ?? this.error,
      );
}

// ───────────────────────────── controller ─────────────────────────────

/// Reactive recalculation engine for one trip.
///
/// Listens to participants, bills, contributions and handovers. ANY change
/// — a new bill, a 21st participant, someone removed, a settle-up payment —
/// re-runs [computeSplit] over every entry, so all shares and balances update
/// instantly on every phone without editing old bills.
class EventSplitController extends StateNotifier<EventSplitState> {
  EventSplitController(this._ref, this.eventId) : super(const EventSplitState()) {
    _ref.listen<AsyncValue<List<TripParticipant>>>(
      eventParticipantsProvider(eventId),
      (_, next) => _ingest(next, (v) => _participants = v),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<EventExpense>>>(
      expensesProvider(eventId),
      (_, next) => _ingest(next, (v) => _expenses = v),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<Contribution>>>(
      contributionsProvider(eventId),
      (_, next) => _ingest(next, (v) => _contributions = v),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<CashTransfer>>>(
      transfersProvider(eventId),
      (_, next) => _ingest(next, (v) => _transfers = v),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final String eventId;

  List<TripParticipant>? _participants;
  List<EventExpense>? _expenses;
  List<Contribution>? _contributions;
  List<CashTransfer>? _transfers;
  Timer? _noteTimer;

  EventSplitRepository get _splitRepo => _ref.read(eventSplitRepositoryProvider);
  AppUser? get _user => _ref.read(appUserProvider).valueOrNull;

  void _ingest<T>(AsyncValue<T> value, void Function(T) assign) {
    if (!mounted) return;
    if (value.hasError) {
      state = state.copyWith(loading: false, error: '${value.error}');
      return;
    }
    if (!value.hasValue) return;
    assign(value.requireValue);
    _recompute();
  }

  void _recompute() {
    final participants = _participants;
    final expenses = _expenses;
    if (participants == null || expenses == null || _contributions == null || _transfers == null) return;

    final before = state.loading ? null : state;
    final summary = computeSplit(
      participants: participants,
      expenses: expenses,
      contributions: _contributions!,
      transfers: _transfers!,
    );
    final note = before == null ? null : _describeChange(before, participants, expenses, summary);

    state = state.copyWith(
      loading: false,
      participants: participants,
      expenses: expenses,
      summary: summary,
      changeNote: note,
    );
    if (note != null) {
      _noteTimer?.cancel();
      _noteTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) state = state.copyWith(clearNote: true);
      });
    }
  }

  /// Human explanation of WHY the per-person share just changed.
  String? _describeChange(
    EventSplitState before,
    List<TripParticipant> participants,
    List<EventExpense> expenses,
    SplitSummary after,
  ) {
    final oldShare = before.summary.perPersonPaise;
    final newShare = after.perPersonPaise;
    if ((oldShare - newShare).abs() < 1) return null;
    final shareText = '${formatPaise(oldShare, exact: true)} → ${formatPaise(newShare, exact: true)}';

    final wasActive = {for (final p in before.participants) if (p.active) p.id};
    final nowActive = {for (final p in participants) if (p.active) p.id};
    final joined = participants.where((p) => p.active && !wasActive.contains(p.id)).map((p) => p.name).toList();
    final left = before.participants.where((p) => wasActive.contains(p.id) && !nowActive.contains(p.id)).map((p) => p.name).toList();
    final oldBills = {for (final e in before.expenses) e.id};
    final newBills = expenses.where((e) => !oldBills.contains(e.id)).toList();

    String names(List<String> n) => n.length <= 2 ? n.join(' & ') : '${n.first} +${n.length - 1}';
    if (joined.isNotEmpty) return '${names(joined)} joined · share $shareText';
    if (left.isNotEmpty) return '${names(left)} removed · share $shareText';
    if (newBills.isNotEmpty) {
      final b = newBills.first;
      return '${b.description} ${formatMoney(b.amount)} added · share $shareText';
    }
    return 'Bills updated · share $shareText';
  }

  /// Per-person share if a bill of [amountRupees] were added now.
  double previewShareWith(double amountRupees) {
    final n = state.summary.activeCount;
    if (n == 0) return 0;
    return (state.summary.totalCostPaise + toPaise(amountRupees)) / n;
  }

  // ───────────────────────── actions ─────────────────────────

  /// Admin: add people (Kuri / community roster or guests).
  Future<void> addParticipants(List<ParticipantDraft> drafts) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null || drafts.isEmpty) return;
    await _splitRepo.addParticipants(eventId, drafts, byUid: uid);
  }

  /// Member: "Join this trip".
  Future<void> joinTrip() async {
    final user = _user;
    final id = participantIdFor(user);
    if (user == null || id == null) throw StateError('Only roster members can join themselves.');
    await _splitRepo.joinSelf(
      eventId,
      participantId: id,
      name: user.name,
      kind: user.memberId != null ? ParticipantKind.kuri : ParticipantKind.community,
      uid: user.uid,
    );
  }

  /// Admin: include / exclude from the split.
  Future<void> setActive(String participantId, bool active) =>
      _splitRepo.setActive(eventId, participantId, active);

  /// Log a bill. It is split across all ACTIVE participants immediately.
  Future<void> addBill({
    required String title,
    required ExpenseCategory category,
    required double amount,
    required TripParticipant paidBy,
  }) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(eventsRepositoryProvider).addExpense(
          eventId: eventId,
          category: category,
          amount: amount,
          paidById: paidBy.id,
          paidByName: paidBy.name,
          description: title,
          // Informational only — the engine always splits across the
          // CURRENT active participants.
          splitCount: state.summary.activeCount == 0 ? 1 : state.summary.activeCount,
          byUid: uid,
        );
  }

  Future<void> deleteBill(String expenseId) => _splitRepo.deleteExpense(eventId, expenseId);

  /// Record "A paid B" from the settle-up plan. Stored as a cash handover,
  /// which moves both balances towards zero.
  Future<void> recordSettlement(SettlementStep step) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(eventsRepositoryProvider).addTransfer(
          eventId: eventId,
          fromId: step.fromId,
          fromName: step.fromName,
          toId: step.toId,
          toName: step.toName,
          amount: toRupees(step.amountPaise),
          note: 'Settle-up payment',
          byUid: uid,
        );
  }

  /// One-tap WhatsApp group summary.
  String whatsappSummary(EventFund event) {
    final s = state.summary;
    final b = StringBuffer()
      ..writeln('🧾 *${event.title}* — Expense summary')
      ..writeln('Total trip cost: *${formatPaise(s.totalCostPaise)}*')
      ..writeln('Participants: ${s.activeCount} · Per person: *${formatPaise(s.perPersonPaise, exact: true)}*')
      ..writeln();

    final bills = state.expenses.reversed.toList(); // oldest first
    if (bills.isNotEmpty) {
      b.writeln('*Bills (${bills.length})*');
      for (var i = 0; i < bills.length && i < 25; i++) {
        final e = bills[i];
        b.writeln('${i + 1}. ${e.description} — ${formatMoney(e.amount)} (paid by ${e.paidByName})');
      }
      if (bills.length > 25) b.writeln('…and ${bills.length - 25} more');
      b.writeln();
    }

    b.writeln('*Balances*');
    for (final x in s.balances) {
      final line = switch (x.status) {
        NetStatus.getsBack => '🟢 ${x.name} — gets back ${formatPaise(x.netPaise)} (തിരികെ ലഭിക്കണം)',
        NetStatus.owes => '🔴 ${x.name} — owes ${formatPaise(-x.netPaise)} (നൽകാൻ ബാക്കി)',
        NetStatus.settled => '⚪ ${x.name} — settled (തീർപ്പാക്കി)',
      };
      b.writeln(line);
    }

    if (s.settlementPlan.isNotEmpty) {
      b
        ..writeln()
        ..writeln('*Settle up (${s.settlementPlan.length} payments)*');
      for (final step in s.settlementPlan) {
        b.writeln('• ${step.fromName} → ${step.toName}: ${formatPaise(step.amountPaise)}');
      }
    }
    b
      ..writeln()
      ..write('_Calculated by ${AppConstants.appName}_');
    return b.toString();
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    super.dispose();
  }
}
