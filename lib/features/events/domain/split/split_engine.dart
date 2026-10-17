import '../entities/event_models.dart';
import 'trip_participant.dart';

// ════════════════════════════════════════════════════════════════════
//  Dynamic auto-split engine (pure Dart, no Flutter / Firebase).
//
//  Every number is recomputed from the raw entries on each change, so
//  adding a bill, adding a 21st participant or removing one re-splits
//  ALL bills instantly with no manual editing.
//
//  Money is handled in integer paise so shares always add up exactly:
//  ₹20,000 / 21 = 95,238 paise each, with the 2 leftover paise going to
//  the two earliest joiners. Σ shares == total, Σ net balances == 0.
// ════════════════════════════════════════════════════════════════════

int toPaise(num rupees) => (rupees * 100).round();
double toRupees(int paise) => paise / 100;

enum NetStatus { getsBack, owes, settled }

/// Balances within ±₹1 count as settled (paise rounding).
const int settledThresholdPaise = 100;

class ParticipantBalance {
  const ParticipantBalance({
    required this.id,
    required this.name,
    required this.isParticipant,
    required this.isActive,
    required this.paidBillsPaise,
    required this.poolAdjustmentPaise,
    required this.shareDuePaise,
    required this.billCount,
  });

  final String id;
  final String name;

  /// On the participant list at all (active or removed).
  final bool isParticipant;

  /// Currently sharing the cost.
  final bool isActive;

  /// Σ bills this person paid upfront.
  final int paidBillsPaise;

  /// Contributions put into the pool, minus pool cash this person is
  /// holding, plus settle-up payments made. Zero when only bills are used.
  final int poolAdjustmentPaise;

  /// Equal share of the whole trip (0 if not active).
  final int shareDuePaise;
  final int billCount;

  /// Total effectively paid towards the trip.
  int get paidUpfrontPaise => paidBillsPaise + poolAdjustmentPaise;

  /// > 0 gets money back, < 0 still owes.
  int get netPaise => paidUpfrontPaise - shareDuePaise;

  NetStatus get status => netPaise.abs() < settledThresholdPaise
      ? NetStatus.settled
      : netPaise > 0
          ? NetStatus.getsBack
          : NetStatus.owes;
}

/// One "A pays B" instruction of the settle-up plan.
class SettlementStep {
  const SettlementStep({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amountPaise,
  });

  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final int amountPaise;
}

class SplitSummary {
  const SplitSummary({
    required this.totalCostPaise,
    required this.activeCount,
    required this.balances,
    required this.settlementPlan,
    required this.billCount,
  });

  static const empty = SplitSummary(
    totalCostPaise: 0,
    activeCount: 0,
    balances: [],
    settlementPlan: [],
    billCount: 0,
  );

  final int totalCostPaise;
  final int activeCount;
  final List<ParticipantBalance> balances;
  final List<SettlementStep> settlementPlan;
  final int billCount;

  /// Exact per-person share (may have paise, e.g. 95238.09…).
  double get perPersonPaise => activeCount == 0 ? 0 : totalCostPaise / activeCount;

  /// Bills paid by someone who is not on the participant list (legacy data).
  bool get hasOutsidePayers => balances.any((b) => !b.isParticipant && b.paidBillsPaise > 0);

  ParticipantBalance? balanceOf(String id) {
    for (final b in balances) {
      if (b.id == id) return b;
    }
    return null;
  }
}

int _byJoinOrder(TripParticipant a, TripParticipant b) {
  final ja = a.joinedAt?.microsecondsSinceEpoch ?? 0;
  final jb = b.joinedAt?.microsecondsSinceEpoch ?? 0;
  return ja != jb ? ja.compareTo(jb) : a.id.compareTo(b.id);
}

/// Recomputes everything from scratch.
///
/// `net = paidUpfront − shareDue`, where
///   paidUpfront = bills paid
///               + contributions given to the pool
///               − pool cash received and still held
///               + handovers / settle-up payments given − received
/// With bills only (the usual case) that is simply `bills paid − share`.
SplitSummary computeSplit({
  required List<TripParticipant> participants,
  required List<EventExpense> expenses,
  List<Contribution> contributions = const [],
  List<CashTransfer> transfers = const [],
}) {
  final total = expenses.fold<int>(0, (s, e) => s + toPaise(e.amount));

  // 1. Equal shares in exact paise across ACTIVE participants.
  final active = participants.where((p) => p.active).toList()..sort(_byJoinOrder);
  final n = active.length;
  final share = <String, int>{};
  if (n > 0) {
    final base = total ~/ n;
    final remainder = total % n;
    for (var i = 0; i < n; i++) {
      share[active[i].id] = base + (i < remainder ? 1 : 0);
    }
  }

  // 2. What each person has paid.
  final names = <String, String>{for (final p in participants) p.id: p.name};
  final bills = <String, int>{};
  final billCount = <String, int>{};
  final adjust = <String, int>{};
  void add(Map<String, int> m, String id, int v) => m[id] = (m[id] ?? 0) + v;

  for (final e in expenses) {
    add(bills, e.paidById, toPaise(e.amount));
    add(billCount, e.paidById, 1);
    names.putIfAbsent(e.paidById, () => e.paidByName);
  }
  for (final c in contributions) {
    final v = toPaise(c.amount);
    add(adjust, c.memberId, v); // gave money to the pool
    add(adjust, c.holderId, -v); // holds pool cash
    names.putIfAbsent(c.memberId, () => c.memberName);
    names.putIfAbsent(c.holderId, () => c.holderName);
  }
  for (final t in transfers) {
    final v = toPaise(t.amount);
    add(adjust, t.fromId, v);
    add(adjust, t.toId, -v);
    names.putIfAbsent(t.fromId, () => t.fromName);
    names.putIfAbsent(t.toId, () => t.toName);
  }

  // 3. One row per participant + anyone with money activity.
  final byId = {for (final p in participants) p.id: p};
  final ids = <String>{...byId.keys, ...bills.keys, ...adjust.keys};
  final balances = ids
      .map((id) => ParticipantBalance(
            id: id,
            name: names[id] ?? 'Unknown',
            isParticipant: byId.containsKey(id),
            isActive: byId[id]?.active ?? false,
            paidBillsPaise: bills[id] ?? 0,
            poolAdjustmentPaise: adjust[id] ?? 0,
            shareDuePaise: share[id] ?? 0,
            billCount: billCount[id] ?? 0,
          ))
      .where((b) => b.isParticipant || b.paidUpfrontPaise != 0)
      .toList()
    ..sort((a, b) {
      final byNet = b.netPaise.compareTo(a.netPaise); // biggest "gets back" first
      return byNet != 0 ? byNet : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  return SplitSummary(
    totalCostPaise: total,
    activeCount: n,
    balances: balances,
    settlementPlan: planSettlements(balances),
    billCount: expenses.length,
  );
}

/// Greedy minimum-transfer plan: the biggest debtor pays the biggest
/// creditor until one of them is settled. At most (people − 1) payments.
List<SettlementStep> planSettlements(List<ParticipantBalance> balances) {
  final creditors = balances
      .where((b) => b.netPaise >= settledThresholdPaise)
      .map((b) => _Open(b.id, b.name, b.netPaise))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final debtors = balances
      .where((b) => b.netPaise <= -settledThresholdPaise)
      .map((b) => _Open(b.id, b.name, -b.netPaise))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final steps = <SettlementStep>[];
  var i = 0;
  var j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i];
    final c = creditors[j];
    final pay = d.amount < c.amount ? d.amount : c.amount;
    if (pay >= settledThresholdPaise) {
      steps.add(SettlementStep(fromId: d.id, fromName: d.name, toId: c.id, toName: c.name, amountPaise: pay));
    }
    d.amount -= pay;
    c.amount -= pay;
    if (d.amount < settledThresholdPaise) i++;
    if (c.amount < settledThresholdPaise) j++;
  }
  return steps;
}

class _Open {
  _Open(this.id, this.name, this.amount);
  final String id;
  final String name;
  int amount;
}
