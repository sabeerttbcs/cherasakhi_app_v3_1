import '../entities/event_models.dart';

abstract interface class EventsRepository {
  Stream<List<EventFund>> watchEvents();
  Future<void> createEvent({
    required String title,
    required EventCategory category,
    required double perHeadTarget,
    required String description,
    required String byUid,
  });

  Stream<List<Contribution>> watchContributions(String eventId);
  Stream<List<EventExpense>> watchExpenses(String eventId);
  Stream<List<CashTransfer>> watchTransfers(String eventId);

  Future<void> addContribution({
    required String eventId,
    required String memberId,
    required String memberName,
    required double amount,
    required String holderId,
    required String holderName,
    required String note,
    required String byUid,
  });

  /// Uploads [receiptFilePath] (if any) to Storage, then writes the expense.
  Future<void> addExpense({
    required String eventId,
    required ExpenseCategory category,
    required double amount,
    required String paidById,
    required String paidByName,
    required String description,
    required int splitCount,
    String? receiptFilePath,
    required String byUid,
  });

  Future<void> addTransfer({
    required String eventId,
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required double amount,
    required String note,
    required String byUid,
  });
}
