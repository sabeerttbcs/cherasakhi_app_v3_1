/// A person on the general community roster (not necessarily in the Kuri).
/// This text roster is used for event participants; account access is invite-only.
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
    this.status = 'active',
  });

  final String uid;
  final String name;
  final String? phone;
  final bool isAdmin;
  final bool isKuriMember;
  final String status;
}

class Invitation {
  const Invitation({
    required this.token,
    required this.name,
    required this.phone,
    required this.status,
    this.note = '',
    this.expiresAt,
    this.createdAt,
  });

  final String token;
  final String name;
  final String phone;
  final String status;
  final String note;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending' && expiresAt != null && expiresAt!.isAfter(DateTime.now());
}
