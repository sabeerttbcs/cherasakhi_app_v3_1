import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/features/events/domain/entities/event_models.dart';
import 'package:kuri_collective/features/events/domain/split/split_engine.dart';
import 'package:kuri_collective/features/events/domain/split/trip_participant.dart';

List<TripParticipant> people(int n) => List.generate(
      n,
      (i) => TripParticipant(
        id: 'm${(i + 1).toString().padLeft(2, '0')}',
        name: 'Member ${i + 1}',
        kind: ParticipantKind.kuri,
        joinedAt: DateTime(2026, 10, 1).add(Duration(minutes: i)),
      ),
    );

EventExpense bill(String paidBy, double amount, [String title = 'Bus Rental']) => EventExpense(
      id: '$paidBy-$amount',
      category: ExpenseCategory.transport,
      amount: amount,
      paidById: paidBy,
      paidByName: paidBy,
      description: title,
      splitCount: 1,
    );

int sumNet(SplitSummary s) => s.balances.fold(0, (t, b) => t + b.netPaise);

void main() {
  test('20 members, ₹20,000 bus paid by member A', () {
    final s = computeSplit(participants: people(20), expenses: [bill('m01', 20000)]);
    expect(s.totalCostPaise, 2000000);
    expect(s.perPersonPaise, 100000); // ₹1,000
    expect(s.balanceOf('m01')!.netPaise, 1900000); // gets back ₹19,000
    expect(s.balanceOf('m01')!.status, NetStatus.getsBack);
    expect(s.balanceOf('m02')!.netPaise, -100000); // owes ₹1,000
    expect(s.balanceOf('m02')!.status, NetStatus.owes);
    expect(sumNet(s), 0);
  });

  test('21st member joins → every bill re-splits instantly, paise-exact', () {
    final s = computeSplit(participants: people(21), expenses: [bill('m01', 20000)]);
    final shares = s.balances.map((b) => b.shareDuePaise).toList();
    expect(shares.reduce((a, b) => a + b), 2000000); // Σ shares == total
    expect(shares.reduce((a, b) => a < b ? a : b), 95238); // ₹952.38
    expect(shares.reduce((a, b) => a > b ? a : b), 95239);
    expect(s.balanceOf('m21')!.netPaise, -95238); // newcomer owes ~₹952
    expect(s.balanceOf('m01')!.netPaise, 1904761);
    expect(sumNet(s), 0);
  });

  test('removed participant keeps credit for bills paid, but no share', () {
    final ps = [
      const TripParticipant(id: 'A', name: 'A', kind: ParticipantKind.kuri, active: false),
      const TripParticipant(id: 'B', name: 'B', kind: ParticipantKind.kuri),
      const TripParticipant(id: 'C', name: 'C', kind: ParticipantKind.kuri),
    ];
    final s = computeSplit(participants: ps, expenses: [bill('A', 1000)]);
    expect(s.activeCount, 2);
    expect(s.balanceOf('A')!.netPaise, 100000);
    expect(s.balanceOf('B')!.netPaise, -50000);
  });

  test('pool contributions + bills paid from pool cash reconcile', () {
    final ps = [
      TripParticipant(id: 'A', name: 'A', kind: ParticipantKind.kuri, joinedAt: DateTime(2026, 1, 1)),
      TripParticipant(id: 'B', name: 'B', kind: ParticipantKind.kuri, joinedAt: DateTime(2026, 1, 2)),
      TripParticipant(id: 'H', name: 'H', kind: ParticipantKind.kuri, joinedAt: DateTime(2026, 1, 3)),
    ];
    final s = computeSplit(
      participants: ps,
      expenses: [bill('H', 900, 'Food & Tea'), bill('A', 300, 'Snacks')],
      contributions: const [
        Contribution(id: 'c1', memberId: 'A', memberName: 'A', amount: 500, holderId: 'H', holderName: 'H'),
        Contribution(id: 'c2', memberId: 'B', memberName: 'B', amount: 500, holderId: 'H', holderName: 'H'),
      ],
    );
    expect(s.balanceOf('A')!.netPaise, 40000);
    expect(s.balanceOf('B')!.netPaise, 10000);
    expect(s.balanceOf('H')!.netPaise, -50000);
    expect(sumNet(s), 0);
    final plan = s.settlementPlan;
    expect(plan.length, 2);
    expect(plan.first.fromId, 'H');
    expect(plan.first.toId, 'A');
    expect(plan.first.amountPaise, 40000);
  });

  test('settle-up payment recorded as a handover settles both sides', () {
    final ps = people(2);
    final s = computeSplit(
      participants: ps,
      expenses: [bill('m01', 1000)],
      transfers: const [CashTransfer(id: 't', fromId: 'm02', fromName: 'B', toId: 'm01', toName: 'A', amount: 500)],
    );
    expect(s.balanceOf('m01')!.status, NetStatus.settled);
    expect(s.balanceOf('m02')!.status, NetStatus.settled);
    expect(s.settlementPlan, isEmpty);
  });

  test('settle-up plan needs at most n−1 payments', () {
    final s = computeSplit(participants: people(21), expenses: [bill('m01', 20000), bill('m05', 4200, 'Food')]);
    expect(s.settlementPlan.length, lessThanOrEqualTo(20));
    final moved = s.settlementPlan.fold<int>(0, (t, x) => t + x.amountPaise);
    final owed = s.balances.where((b) => b.netPaise < 0).fold<int>(0, (t, b) => t - b.netPaise);
    expect((moved - owed).abs(), lessThan(settledThresholdPaise * 21));
  });

  test('no participants → total still shown, no shares', () {
    final s = computeSplit(participants: const [], expenses: [bill('x', 500)]);
    expect(s.totalCostPaise, 50000);
    expect(s.activeCount, 0);
    expect(s.perPersonPaise, 0);
    expect(s.hasOutsidePayers, isTrue);
  });
}
