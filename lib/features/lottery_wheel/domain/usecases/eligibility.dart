import '../../../kuri/domain/entities/member.dart';
import '../../../kuri/domain/entities/payment.dart';

class EligibilityResult {
  const EligibilityResult({required this.eligible, required this.unpaid, required this.alreadyWon});

  /// Only these names appear as wheel slices.
  final List<Member> eligible;
  final List<Member> unpaid;
  final List<Member> alreadyWon;
}

/// HARD CONSTRAINTS:
///  1. Member must be PAID for the draw month.
///  2. Member must NOT have claimed the Kuri earlier in this cycle.
/// (Inactive members are never eligible.)
EligibilityResult evaluateEligibility({
  required List<Member> members,
  required Map<String, Payment> payments,
  required Set<String> claimedMemberIds,
}) {
  final eligible = <Member>[];
  final unpaid = <Member>[];
  final won = <Member>[];
  for (final m in members) {
    if (!m.isActive) continue;
    if (claimedMemberIds.contains(m.id)) {
      won.add(m);
      continue;
    }
    if (payments[m.id]?.paid ?? false) {
      eligible.add(m);
    } else {
      unpaid.add(m);
    }
  }
  eligible.sort((a, b) => a.seatNo.compareTo(b.seatNo));
  return EligibilityResult(eligible: eligible, unpaid: unpaid, alreadyWon: won);
}
