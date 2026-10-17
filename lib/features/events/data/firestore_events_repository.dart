import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/firestore_utils.dart';
import '../domain/entities/event_models.dart';
import '../domain/repositories/events_repository.dart';

class FirestoreEventsRepository implements EventsRepository {
  FirestoreEventsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _events => _db.collection('events');
  CollectionReference<Json> _sub(String eventId, String name) => _events.doc(eventId).collection(name);

  // ---------- Events ----------
  @override
  Stream<List<EventFund>> watchEvents() => _events.orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) {
          final m = d.data();
          return EventFund(
            id: d.id,
            title: asString(m['title']),
            category: EventCategory.values.asNameMap()[m['category']] ?? EventCategory.other,
            perHeadTarget: asDouble(m['perHeadTarget']),
            description: asString(m['description']),
            isSettled: m['isSettled'] == true,
            createdAt: tsToDate(m['createdAt']),
          );
        }).toList(growable: false),
      );

  @override
  Future<void> createEvent({
    required String title,
    required EventCategory category,
    required double perHeadTarget,
    required String description,
    required String byUid,
  }) =>
      _events.doc().set({
        'title': title.trim(),
        'category': category.name,
        'perHeadTarget': perHeadTarget,
        'description': description.trim(),
        'isSettled': false,
        'createdBy': byUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // ---------- Contributions ----------
  @override
  Stream<List<Contribution>> watchContributions(String eventId) =>
      _sub(eventId, 'contributions').orderBy('at', descending: true).snapshots().map(
            (s) => s.docs.map((d) {
              final m = d.data();
              return Contribution(
                id: d.id,
                memberId: asString(m['memberId']),
                memberName: asString(m['memberName']),
                amount: asDouble(m['amount']),
                holderId: asString(m['holderId']),
                holderName: asString(m['holderName']),
                note: asString(m['note']),
                at: tsToDate(m['at']),
              );
            }).toList(growable: false),
          );

  @override
  Future<void> addContribution({
    required String eventId,
    required String memberId,
    required String memberName,
    required double amount,
    required String holderId,
    required String holderName,
    required String note,
    required String byUid,
  }) =>
      _sub(eventId, 'contributions').doc().set({
        'memberId': memberId,
        'memberName': memberName,
        'amount': amount,
        'holderId': holderId,
        'holderName': holderName,
        'note': note.trim(),
        'createdBy': byUid,
        'at': FieldValue.serverTimestamp(),
      });

  // ---------- Expenses ----------
  @override
  Stream<List<EventExpense>> watchExpenses(String eventId) =>
      _sub(eventId, 'expenses').orderBy('at', descending: true).snapshots().map(
            (s) => s.docs.map((d) {
              final m = d.data();
              return EventExpense(
                id: d.id,
                category: ExpenseCategory.values.asNameMap()[m['category']] ?? ExpenseCategory.misc,
                amount: asDouble(m['amount']),
                paidById: asString(m['paidById']),
                paidByName: asString(m['paidByName']),
                description: asString(m['description']),
                splitCount: asInt(m['splitCount'], 1),
                at: tsToDate(m['at']),
                createdBy: m['createdBy'] as String?,
              );
            }).toList(growable: false),
          );

  @override
  Future<void> addExpense({
    required String eventId,
    required ExpenseCategory category,
    required double amount,
    required String paidById,
    required String paidByName,
    required String description,
    required int splitCount,
    required String byUid,
  }) async {
    final doc = _sub(eventId, 'expenses').doc();
    await doc.set({
      'category': category.name,
      'amount': amount,
      'paidById': paidById,
      'paidByName': paidByName,
      'description': description.trim(),
      'splitCount': splitCount,
      'createdBy': byUid,
      'at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Cash transfers ----------
  @override
  Stream<List<CashTransfer>> watchTransfers(String eventId) =>
      _sub(eventId, 'transfers').orderBy('at', descending: true).snapshots().map(
            (s) => s.docs.map((d) {
              final m = d.data();
              return CashTransfer(
                id: d.id,
                fromId: asString(m['fromId']),
                fromName: asString(m['fromName']),
                toId: asString(m['toId']),
                toName: asString(m['toName']),
                amount: asDouble(m['amount']),
                note: asString(m['note']),
                at: tsToDate(m['at']),
              );
            }).toList(growable: false),
          );

  @override
  Future<void> addTransfer({
    required String eventId,
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required double amount,
    required String note,
    required String byUid,
  }) =>
      _sub(eventId, 'transfers').doc().set({
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'toName': toName,
        'amount': amount,
        'note': note.trim(),
        'createdBy': byUid,
        'at': FieldValue.serverTimestamp(),
      });
}
