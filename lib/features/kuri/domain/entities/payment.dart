/// Installment status of one member for one month.
/// Firestore doc id: `{monthKey}_{memberId}`.
class Payment {
  const Payment({
    required this.memberId,
    required this.monthKey,
    required this.paid,
    required this.amount,
    this.paidAt,
    this.markedBy,
  });

  final String memberId;
  final String monthKey;
  final bool paid;
  final double amount;
  final DateTime? paidAt;
  final String? markedBy;
}
