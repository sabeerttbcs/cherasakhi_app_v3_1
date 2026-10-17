/// A member of the 60-seat collective. Pure Dart — no Firebase types.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.seatNo,
    this.isActive = true,
    this.joinedAt,
  });

  final String id;
  final String name;

  /// E.164, e.g. +919876543210 (must match the Phone-Auth number).
  final String phone;
  final int seatNo;
  final bool isActive;
  final DateTime? joinedAt;

  Member copyWith({String? name, String? phone, int? seatNo, bool? isActive}) => Member(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        seatNo: seatNo ?? this.seatNo,
        isActive: isActive ?? this.isActive,
        joinedAt: joinedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Member &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.seatNo == seatNo &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(id, name, phone, seatNo, isActive);
}
