import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/community_models.dart';

class CommunityRepository {
  CommunityRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _community => _db.collection('community');

  Stream<List<CommunityPerson>> watchRoster() => _community.orderBy('name').snapshots().map(
        (s) => s.docs
            .map((d) => CommunityPerson(
                  id: d.id,
                  name: asString(d.data()['name']),
                  phone: asString(d.data()['phone']),
                  addedAt: tsToDate(d.data()['addedAt']),
                ))
            .toList(growable: false),
      );

  Future<void> add({required String name, required String phone}) => _community.add({
        'name': name.trim(),
        'phone': phone,
        'addedAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String id) => _community.doc(id).delete();

  /// Admin only (rules): every registered profile.
  Stream<List<RegisteredUser>> watchRegisteredUsers() => _db.collection('users').snapshots().map((s) {
        final list = s.docs.map((d) {
          final m = d.data();
          return RegisteredUser(
            uid: d.id,
            name: asString(m['name'], 'Member'),
            phone: m['phone'] as String?,
            isAdmin: m['role'] == 'admin',
            isKuriMember: m['isKuriMember'] as bool? ?? m['memberId'] != null,
          );
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Grant / revoke Kuri access for an already-registered user.
  Future<void> setKuriMember(String uid, bool value) =>
      _db.collection('users').doc(uid).update({'isKuriMember': value});
}
