import 'member.dart';
import 'payment.dart';

class LedgerSummary {
  const LedgerSummary({
    required this.totalMembers,
    required this.paidCount,
    required this.target,
    required this.collected,
  });

  final int totalMembers;
  final int paidCount;
  final double target;
  final double collected;

  int get unpaidCount => totalMembers - paidCount;
  double get deficit => (target - collected).clamp(0.0, double.infinity).toDouble();
  double get progress => target <= 0 ? 0 : (collected / target).clamp(0.0, 1.0).toDouble();

  factory LedgerSummary.compute({
    required List<Member> members,
    required Map<String, Payment> payments,
    required double installment,
  }) {
    final active = members.where((m) => m.isActive);
    var total = 0;
    var paid = 0;
    var collected = 0.0;
    for (final m in active) {
      total++;
      final p = payments[m.id];
      if (p != null && p.paid) {
        paid++;
        collected += p.amount;
      }
    }
    return LedgerSummary(
      totalMembers: total,
      paidCount: paid,
      target: installment * total,
      collected: collected,
    );
  }
}
