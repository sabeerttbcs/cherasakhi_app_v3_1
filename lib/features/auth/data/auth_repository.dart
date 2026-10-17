import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/firestore_utils.dart';
import '../../../core/utils/formatters.dart';
import '../domain/app_user.dart';

class InviteInfo {
  const InviteInfo({
    required this.token,
    required this.name,
    required this.phone,
    required this.status,
    required this.expiresAt,
    this.note = '',
  });

  final String token;
  final String name;
  final String phone;
  final String status;
  final DateTime? expiresAt;
  final String note;

  bool get isPending => status == 'pending' && expiresAt != null && expiresAt!.isAfter(DateTime.now());
}

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> loginWithPhone({required String phone, required String password}) async {
    final normalized = normalizePhone(phone);
    if (normalized.length < 11) throw const FormatException('Enter a valid mobile number');
    await _auth.signInWithEmailAndPassword(email: phoneLoginAlias(normalized), password: password.trim());
  }

  Future<InviteInfo?> getInvite(String token) async {
    final snap = await _db.collection('invitations').doc(token.trim()).get(const GetOptions(source: Source.server));
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    return InviteInfo(
      token: snap.id,
      name: asString(data['name'], 'Member'),
      phone: asString(data['phone']),
      status: asString(data['status'], 'pending'),
      expiresAt: tsToDate(data['expiresAt']),
      note: asString(data['note']),
    );
  }

  Future<void> acceptInvite({required String token, required String password}) async {
    if (password.trim().length < 6) throw const FormatException('Password must be at least 6 characters');
    final invite = await getInvite(token);
    if (invite == null || !invite.isPending) throw StateError('This invitation is invalid or has expired');

    final normalizedPhone = normalizePhone(invite.phone);
    final alias = phoneLoginAlias(normalizedPhone);
    final credential = await _auth.createUserWithEmailAndPassword(email: alias, password: password.trim());
    final user = credential.user;
    if (user == null) throw StateError('Could not create the member account');

    final userRef = _db.collection('users').doc(user.uid);
    final inviteRef = _db.collection('invitations').doc(token.trim());
    final batch = _db.batch();
    batch.set(userRef, {
      'name': invite.name,
      'phone': normalizedPhone,
      'loginAlias': alias,
      'role': 'member',
      'status': 'active',
      'isKuriMember': false,
      'inviteToken': token.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(inviteRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Stream<AppUser?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return AppUser(
        uid: uid,
        name: asString(data['name'], 'Member'),
        role: data['role'] == 'admin' ? UserRole.admin : UserRole.member,
        phone: data['phone'] as String?,
        memberId: data['memberId'] as String?,
        communityId: data['communityId'] as String?,
        isKuriMember: data['isKuriMember'] as bool? ?? data['memberId'] != null,
        status: asString(data['status'], 'active'),
      );
    });
  }

  static String generateInviteToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
