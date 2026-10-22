import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/community_models.dart';

class CommunityRepository {
  CommunityRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _community => _db.collection('community');
  CollectionReference<Json> get _invitations => _db.collection('invitations');

  Stream<List<CommunityPerson>> watchRoster() =>
      _community.orderBy('name').snapshots().map(
            (s) => s.docs
                .map((d) => CommunityPerson(
                      id: d.id,
                      name: asString(d.data()['name']),
                      phone: asString(d.data()['phone']),
                      addedAt: tsToDate(d.data()['addedAt']),
                    ))
                .toList(growable: false),
          );

  Future<void> add({required String name, required String phone}) =>
      _community.add({
        'name': name.trim(),
        'phone': phone,
        'addedAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String id) => _community.doc(id).delete();

  /// Admin only (rules): every registered profile.
  Stream<List<RegisteredUser>> watchRegisteredUsers() =>
      _db.collection('users').snapshots().map((s) {
        final list = s.docs.map((d) {
          final m = d.data();
          return RegisteredUser(
            uid: d.id,
            name: asString(m['name'], 'Member'),
            phone: m['phone'] as String?,
            isAdmin: m['role'] == 'admin',
            isKuriMember: m['isKuriMember'] as bool? ?? m['memberId'] != null,
            status: asString(m['status'], 'active'),
          );
        }).toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Grant / revoke Kuri access for an already-registered user.
  Future<void> setKuriMember(String uid, bool value) =>
      _db.collection('users').doc(uid).update({'isKuriMember': value});

  Stream<List<Invitation>> watchInvitations() =>
      _invitations.snapshots().map((s) {
        final list = s.docs.map((d) {
          final m = d.data();
          return Invitation(
            token: d.id,
            name: asString(m['name'], 'Member'),
            phone: asString(m['phone']),
            status: asString(m['status'], 'pending'),
            note: asString(m['note']),
            expiresAt: tsToDate(m['expiresAt']),
            createdAt: tsToDate(m['createdAt']),
          );
        }).toList();
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Future<String> createInvitation(
      {required String name, required String phone, String note = ''}) async {
    final token = AuthRepository.generateInviteToken();
    final normalized = normalizePhone(phone);
    await _invitations.doc(token).set({
      'token': token,
      'name': name.trim(),
      'phone': normalized,
      'loginAlias': phoneLoginAlias(normalized),
      'note': note.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
    return token;
  }

  /// Cancels an invitation and creates one replacement in the same batch.
  /// Existing security rules permit only an admin to cancel/create, so a
  /// number correction never edits an invitation after it has been sent.
  Future<String> replaceInvitation({
    required String token,
    required String name,
    required String phone,
    String note = '',
  }) async {
    final newToken = AuthRepository.generateInviteToken();
    final normalized = normalizePhone(phone);
    final batch = _db.batch();
    batch.update(_invitations.doc(token), {'status': 'cancelled'});
    batch.set(_invitations.doc(newToken), {
      'token': newToken,
      'name': name.trim(),
      'phone': normalized,
      'loginAlias': phoneLoginAlias(normalized),
      'note': note.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
    await batch.commit();
    return newToken;
  }

  Future<void> cancelInvitation(String token) =>
      _invitations.doc(token).update({'status': 'cancelled'});

  Future<void> setMemberStatus(String uid, bool enabled) => _db
      .collection('users')
      .doc(uid)
      .update({'status': enabled ? 'active' : 'disabled'});
}
