/// Permanent marker that a member has won (claimed) the Kuri in a cycle.
/// Doc: `cycles/{cycleId}/claims/{memberId}` — create-only in security rules.
class Claim {
  const Claim({
    required this.memberId,
    required this.memberName,
    required this.claimedMonth,
    required this.amount,
    this.hasClaimed = true,
    this.claimedAt,
  });

  final String memberId;
  final String memberName;
  final bool hasClaimed;
  final String claimedMonth;
  final double amount;
  final DateTime? claimedAt;
}
