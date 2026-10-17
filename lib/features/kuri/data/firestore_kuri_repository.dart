import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/entities/claim.dart';
import '../domain/entities/kuri_cycle.dart';
import '../domain/entities/member.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/kuri_repository.dart';
import 'kuri_mappers.dart';

class FirestoreKuriRepository implements KuriRepository {
  FirestoreKuriRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _members => _db.collection('members');
  CollectionReference<Json> get _cycles => _db.collection('cycles');

  @override
  Stream<List<Member>> watchMembers() => _members
      .orderBy('seatNo')
      .snapshots()
      .map((s) => s.docs.map(memberFromDoc).toList(growable: false));

  @override
  Future<void> addMember({required String name, required String phone, required int seatNo}) async {
    await _members.add({
      'name': name.trim(),
      'phone': phone,
      'seatNo': seatNo,
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateMember(Member member) => _members.doc(member.id).update({
        'name': member.name.trim(),
        'phone': member.phone,
        'seatNo': member.seatNo,
        'isActive': member.isActive,
      });

  @override
  Stream<KuriCycle?> watchActiveCycle() => _cycles
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : cycleFromDoc(s.docs.first));

  @override
  Future<void> startCycle({
    required String name,
    required String startMonth,
    required int durationMonths,
    required double monthlyInstallment,
    required String byUid,
  }) async {
    final actives = await _cycles.where('status', isEqualTo: 'active').get();
    final batch = _db.batch();
    for (final d in actives.docs) {
      batch.update(d.reference, {'status': 'closed', 'closedAt': FieldValue.serverTimestamp()});
    }
    batch.set(_cycles.doc(), {
      'name': name.trim(),
      'startMonth': startMonth,
      'durationMonths': durationMonths,
      'monthlyInstallment': monthlyInstallment,
      'status': 'active',
      'createdBy': byUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Stream<Map<String, Payment>> watchPayments(String cycleId, String monthKey) => _cycles
          .doc(cycleId)
          .collection('payments')
          .where('monthKey', isEqualTo: monthKey)
          .snapshots(includeMetadataChanges: false)
          .map((s) {
        final map = <String, Payment>{};
        for (final d in s.docs) {
          final p = paymentFromDoc(d);
          map[p.memberId] = p;
        }
        return map;
      });

  @override
  Future<void> setPayment({
    required String cycleId,
    required String monthKey,
    required Member member,
    required bool paid,
    required double amount,
    required String byUid,
  }) {
    // Local write is applied to the cache instantly (latency compensation),
    // so the UI toggles at once even when offline.
    return _cycles.doc(cycleId).collection('payments').doc('${monthKey}_${member.id}').set({
      'memberId': member.id,
      'memberName': member.name,
      'monthKey': monthKey,
      'paid': paid,
      'amount': paid ? amount : 0,
      'paidAt': paid ? FieldValue.serverTimestamp() : null,
      'markedBy': byUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Claim>> watchClaims(String cycleId) => _cycles
      .doc(cycleId)
      .collection('claims')
      .snapshots()
      .map((s) => s.docs.map(claimFromDoc).where((c) => c.hasClaimed).toList(growable: false));
}
