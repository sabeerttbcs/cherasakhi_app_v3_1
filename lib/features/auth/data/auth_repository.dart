import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> sendOtp({
    required String phone,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      // Android can auto-read the SMS and sign in instantly.
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) => onError(e.message ?? e.code),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> verifyOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }

  /// Admin fallback: Firebase Email/Password account where the password is
  /// the admin's 6+ digit PIN.
  Future<void> adminPinLogin({required String adminId, required String pin}) async {
    await _auth.signInWithEmailAndPassword(email: adminId.trim(), password: pin.trim());
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
        // Older profiles have no flag: they were all created from the Kuri roster.
        isKuriMember: data['isKuriMember'] as bool? ?? data['memberId'] != null,
      );
    });
  }

  /// First phone login: link the Firebase user to the roster record whose
  /// phone matches the verified number.
  ///   1. `members` (Kuri roster)      → isKuriMember = true
  ///   2. `community` (general roster) → isKuriMember = false
  /// Returns false if the number is on neither roster.
  Future<bool> bootstrapMemberProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final existing = await userRef.get(const GetOptions(source: Source.server));
    if (existing.exists) return true;

    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) return false;

    final kuri = await _db
        .collection('members')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (kuri.docs.isNotEmpty) {
      final member = kuri.docs.first;
      await userRef.set({
        'phone': phone,
        'name': asString(member.data()['name'], 'Member'),
        'role': 'member',
        'memberId': member.id,
        'isKuriMember': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    }

    final community = await _db
        .collection('community')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (community.docs.isEmpty) return false;

    final person = community.docs.first;
    await userRef.set({
      'phone': phone,
      'name': asString(person.data()['name'], 'Member'),
      'role': 'member',
      'communityId': person.id,
      'isKuriMember': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
