/// Where a participant comes from. Kuri / community participants use the
/// roster id as their participant id, so existing wallet entries (which use
/// member ids for payers / holders) line up automatically.
enum ParticipantKind { kuri, community, guest }

/// `events/{eventId}/participants/{participantId}`
class TripParticipant {
  const TripParticipant({
    required this.id,
    required this.name,
    required this.kind,
    this.active = true,
    this.joinedAt,
    this.leftAt,
  });

  final String id;
  final String name;
  final ParticipantKind kind;

  /// Only active participants share the cost. Toggling this re-splits
  /// every bill instantly.
  final bool active;
  final DateTime? joinedAt;
  final DateTime? leftAt;
}
