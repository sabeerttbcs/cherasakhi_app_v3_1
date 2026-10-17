import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/split/trip_participant.dart';

/// New participant to add. Kuri / community people keep their roster id.
class ParticipantDraft {
  const ParticipantDraft({required this.name, required this.kind, this.rosterId});

  final String name;
  final ParticipantKind kind;

  /// Kuri `members/{id}` or `community/{id}`; null for guests.
  final String? rosterId;
}

/// `events/{eventId}/participants/{participantId}` + bill deletion.
/// Bills themselves are still written by the existing EventsRepository.
class EventSplitRepository {
  EventSplitRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> _participants(String eventId) =>
      _db.collection('events').doc(eventId).collection('participants');

  Stream<List<TripParticipant>> watchParticipants(String eventId) => _participants(eventId).snapshots().map(
        (s) => s.docs.map((d) {
          final m = d.data();
          return TripParticipant(
            id: d.id,
            name: asString(m['name'], 'Member'),
            kind: ParticipantKind.values.asNameMap()[m['kind']] ?? ParticipantKind.guest,
            active: m['active'] as bool? ?? true,
            joinedAt: tsToDate(m['joinedAt']),
            leftAt: tsToDate(m['leftAt']),
          );
        }).toList(growable: false),
      );

  /// Admin: add several people at once (one batch → one recalculation).
  Future<void> addParticipants(String eventId, List<ParticipantDraft> drafts, {required String byUid}) {
    final batch = _db.batch();
    for (final p in drafts) {
      final ref = p.rosterId == null
          ? _participants(eventId).doc('guest_${_participants(eventId).doc().id}')
          : _participants(eventId).doc(p.rosterId);
      batch.set(ref, {
        'name': p.name.trim(),
        'kind': p.kind.name,
        'active': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'addedBy': byUid,
      });
    }
    return batch.commit();
  }

  /// Member joins the trip themselves.
  Future<void> joinSelf(String eventId, {required String participantId, required String name, required ParticipantKind kind, required String uid}) =>
      _participants(eventId).doc(participantId).set({
        'name': name,
        'kind': kind.name,
        'active': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'addedBy': uid,
      });

  /// Admin: include / exclude someone from the split (history is kept).
  Future<void> setActive(String eventId, String participantId, bool active) =>
      _participants(eventId).doc(participantId).update({
        'active': active,
        'leftAt': active ? null : FieldValue.serverTimestamp(),
      });

  Future<void> deleteExpense(String eventId, String expenseId) =>
      _db.collection('events').doc(eventId).collection('expenses').doc(expenseId).delete();
}
