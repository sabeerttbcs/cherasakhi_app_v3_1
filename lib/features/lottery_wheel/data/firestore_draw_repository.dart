import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../../kuri/domain/entities/member.dart';
import '../domain/entities/draw_record.dart';
import '../domain/repositories/draw_repository.dart';

class FirestoreDrawRepository implements DrawRepository {
  FirestoreDrawRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Json> _cycle(String id) => _db.collection('cycles').doc(id);

  @override
  Stream<List<DrawRecord>> watchDraws(String cycleId) => _cycle(cycleId)
      .collection('draws')
      .orderBy('monthKey')
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList(growable: false));

  DrawRecord _fromDoc(JsonDoc d) {
    final m = d.data() ?? const <String, dynamic>{};
    return DrawRecord(
      monthKey: asString(m['monthKey'], d.id),
      winnerId: asString(m['winnerId']),
      winnerName: asString(m['winnerName']),
      winnerSeatNo: asInt(m['winnerSeatNo']),
      amount: asDouble(m['amount']),
      eligibleCount: asInt(m['eligibleCount']),
      drawnAt: tsToDate(m['drawnAt']),
      drawnBy: m['drawnBy'] as String?,
    );
  }

  @override
  Future<DrawRecord> commitDraw({
    required String cycleId,
    required String monthKey,
    required Member winner,
    required double amount,
    required int eligibleCount,
    required String drawnBy,
  }) {
    final cycleRef = _cycle(cycleId);
    final drawRef = cycleRef.collection('draws').doc(monthKey);
    final claimRef = cycleRef.collection('claims').doc(winner.id);
    final payRef = cycleRef.collection('payments').doc('${monthKey}_${winner.id}');

    return _db.runTransaction<DrawRecord>((tx) async {
      final drawSnap = await tx.get(drawRef);
      if (drawSnap.exists) {
        throw const DrawException('The draw for this month is already completed.');
      }
      final claimSnap = await tx.get(claimRef);
      if (claimSnap.exists) {
        throw DrawException('${winner.name} has already won in this cycle.');
      }
      final paySnap = await tx.get(payRef);
      if (paySnap.data()?['paid'] != true) {
        throw DrawException('${winner.name} is not marked PAID for this month.');
      }

      tx.set(drawRef, {
        'monthKey': monthKey,
        'winnerId': winner.id,
        'winnerName': winner.name,
        'winnerSeatNo': winner.seatNo,
        'amount': amount,
        'eligibleCount': eligibleCount,
        'drawnBy': drawnBy,
        'drawnAt': FieldValue.serverTimestamp(),
      });
      tx.set(claimRef, {
        'memberId': winner.id,
        'memberName': winner.name,
        'hasClaimed': true,
        'claimedMonth': monthKey,
        'amount': amount,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      return DrawRecord(
        monthKey: monthKey,
        winnerId: winner.id,
        winnerName: winner.name,
        winnerSeatNo: winner.seatNo,
        amount: amount,
        eligibleCount: eligibleCount,
        drawnAt: DateTime.now(),
        drawnBy: drawnBy,
      );
    }, timeout: const Duration(seconds: 20));
  }
}
