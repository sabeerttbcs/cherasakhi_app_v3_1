import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/features/events/domain/entities/event_models.dart';
import 'package:kuri_collective/features/kuri/domain/entities/ledger_summary.dart';
import 'package:kuri_collective/features/kuri/domain/entities/member.dart';
import 'package:kuri_collective/features/kuri/domain/entities/payment.dart';
import 'package:kuri_collective/features/lottery_wheel/domain/usecases/eligibility.dart';

Member m(String id, int seat, {bool active = true}) =>
    Member(id: id, name: 'Member $id', phone: '+9190000000$seat', seatNo: seat, isActive: active);

Payment p(String id, bool paid) => Payment(memberId: id, monthKey: '2026-10', paid: paid, amount: paid ? 1000 : 0);

void main() {
  group('Pamparam eligibility', () {
    final members = [m('a', 1), m('b', 2), m('c', 3), m('d', 4), m('e', 5, active: false)];
    final payments = {'a': p('a', true), 'b': p('b', true), 'c': p('c', false), 'e': p('e', true)};

    test('only PAID and NOT-yet-won active members are eligible', () {
      final r = evaluateEligibility(members: members, payments: payments, claimedMemberIds: {'b'});
      expect(r.eligible.map((x) => x.id), ['a']);
      expect(r.unpaid.map((x) => x.id).toSet(), {'c', 'd'});
      expect(r.alreadyWon.map((x) => x.id), ['b']);
    });

    test('previous winner stays excluded even if paid', () {
      final r = evaluateEligibility(members: members, payments: payments, claimedMemberIds: {'a', 'b'});
      expect(r.eligible, isEmpty);
    });
  });

  test('ledger summary metrics', () {
    final s = LedgerSummary.compute(
      members: [m('a', 1), m('b', 2), m('c', 3)],
      payments: {'a': p('a', true), 'b': p('b', true)},
      installment: 1000,
    );
    expect(s.paidCount, 2);
    expect(s.target, 3000);
    expect(s.collected, 2000);
    expect(s.deficit, 1000);
  });

  test('cash holder balances', () {
    final l = EventLedger.compute(
      contributions: const [
        Contribution(id: '1', memberId: 'a', memberName: 'A', amount: 500, holderId: 'h', holderName: 'H'),
        Contribution(id: '2', memberId: 'b', memberName: 'B', amount: 500, holderId: 'h', holderName: 'H'),
      ],
      expenses: const [
        EventExpense(id: 'x', category: ExpenseCategory.dining, amount: 300, paidById: 'k', paidByName: 'K', description: 'Lunch', splitCount: 2),
      ],
      transfers: const [
        CashTransfer(id: 't', fromId: 'h', fromName: 'H', toId: 'k', toName: 'K', amount: 200),
      ],
    );
    final h = l.holders.firstWhere((x) => x.id == 'h');
    final k = l.holders.firstWhere((x) => x.id == 'k');
    expect(h.balance, 800);
    expect(k.balance, -100); // fund owes K 100
    expect(l.balance, 700);
  });
}
