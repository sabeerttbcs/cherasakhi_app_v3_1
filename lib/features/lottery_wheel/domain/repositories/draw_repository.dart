import '../../../kuri/domain/entities/member.dart';
import '../entities/draw_record.dart';

class DrawException implements Exception {
  const DrawException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class DrawRepository {
  Stream<List<DrawRecord>> watchDraws(String cycleId);

  /// Atomically records the winner and permanently tags them
  /// `hasClaimed = true, claimedMonth = monthKey`. Throws [DrawException]
  /// if the month was already drawn, the member already won, or is unpaid.
  Future<DrawRecord> commitDraw({
    required String cycleId,
    required String monthKey,
    required Member winner,
    required double amount,
    required int eligibleCount,
    required String drawnBy,
  });
}
