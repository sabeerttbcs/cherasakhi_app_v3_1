enum UserRole { admin, member }

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    this.phone,
    this.memberId,
    this.communityId,
    this.isKuriMember = false,
  });

  final String uid;
  final String name;
  final UserRole role;
  final String? phone;

  /// Link to `members/{memberId}` (the Kuri roster) for Kuri members.
  final String? memberId;

  /// Link to `community/{communityId}` for community-only members.
  final String? communityId;

  /// Enrolled in the monthly Kuri cohort. Only these users (and admins) can
  /// see ledgers, payment checklists and the Pamparam draw.
  final bool isKuriMember;

  // ───────── role-based helpers ─────────
  bool get isAdmin => role == UserRole.admin;

  /// Kuri ledger, history and Pamparam wheel.
  bool get canAccessKuri => isAdmin || isKuriMember;

  /// Mark payments, start cycles, spin the wheel.
  bool get canManageKuri => isAdmin;

  /// Live quiz is open to every registered member. Admins host and know the
  /// answer, so they cannot submit.
  bool get canViewQuiz => true;
  bool get canPlayQuiz => !isAdmin;
  bool get canManageQuiz => isAdmin;

  /// Registered, but not part of the Kuri cohort.
  bool get isCommunityOnly => !isAdmin && !isKuriMember;
}
