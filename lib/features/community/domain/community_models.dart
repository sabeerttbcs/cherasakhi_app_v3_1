/// A person on the general community roster (not necessarily in the Kuri).
/// Being on this list lets them register with phone OTP.
class CommunityPerson {
  const CommunityPerson({required this.id, required this.name, required this.phone, this.addedAt});

  final String id;
  final String name;
  final String phone; // E.164
  final DateTime? addedAt;
}

/// A registered app user, as the admin sees it on the access screen.
class RegisteredUser {
  const RegisteredUser({
    required this.uid,
    required this.name,
    required this.isAdmin,
    required this.isKuriMember,
    this.phone,
  });

  final String uid;
  final String name;
  final String? phone;
  final bool isAdmin;
  final bool isKuriMember;
}
