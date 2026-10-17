/// Result of a monthly Pamparam draw. Doc: `cycles/{cycleId}/draws/{monthKey}`.
class DrawRecord {
  const DrawRecord({
    required this.monthKey,
    required this.winnerId,
    required this.winnerName,
    required this.winnerSeatNo,
    required this.amount,
    required this.eligibleCount,
    this.drawnAt,
    this.drawnBy,
  });

  final String monthKey;
  final String winnerId;
  final String winnerName;
  final int winnerSeatNo;
  final double amount;
  final int eligibleCount;
  final DateTime? drawnAt;
  final String? drawnBy;
}
