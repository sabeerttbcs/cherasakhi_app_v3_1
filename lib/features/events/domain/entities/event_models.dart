enum EventCategory { trip, party, festival, other }

extension EventCategoryX on EventCategory {
  String get label => switch (this) {
        EventCategory.trip => 'Annual Trip',
        EventCategory.party => 'Party',
        EventCategory.festival => 'Festival',
        EventCategory.other => 'Other',
      };

  String get emoji => switch (this) {
        EventCategory.trip => '🚌',
        EventCategory.party => '🎉',
        EventCategory.festival => '🪔',
        EventCategory.other => '✨',
      };
}

enum ExpenseCategory { transport, dining, accommodation, misc }

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.dining => 'Dining',
        ExpenseCategory.accommodation => 'Accommodation',
        ExpenseCategory.misc => 'Misc',
      };
}

/// An isolated sub-fund (e.g. "Munnar Trip 2026", "Onam Celebration").
class EventFund {
  const EventFund({
    required this.id,
    required this.title,
    required this.category,
    required this.perHeadTarget,
    this.description = '',
    this.isSettled = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final EventCategory category;
  final double perHeadTarget;
  final String description;
  final bool isSettled;
  final DateTime? createdAt;
}

/// Money a member paid INTO the fund, and who physically received it.
class Contribution {
  const Contribution({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.holderId,
    required this.holderName,
    this.note = '',
    this.at,
  });

  final String id;
  final String memberId;
  final String memberName;
  final double amount;
  final String holderId;
  final String holderName;
  final String note;
  final DateTime? at;
}

class EventExpense {
  const EventExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paidById,
    required this.paidByName,
    required this.description,
    required this.splitCount,
    this.receiptUrl,
    this.at,
    this.createdBy,
  });

  final String id;
  final ExpenseCategory category;
  final double amount;

  /// The cash holder whose money paid for this.
  final String paidById;
  final String paidByName;
  final String description;
  final int splitCount;
  final String? receiptUrl;
  final DateTime? at;

  /// uid of whoever logged the bill (they may delete it).
  final String? createdBy;

  double get perHead => splitCount <= 0 ? amount : amount / splitCount;
}

/// Physical handover of cash between two holders.
class CashTransfer {
  const CashTransfer({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
    this.note = '',
    this.at,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final double amount;
  final String note;
  final DateTime? at;
}

class HolderBalance {
  const HolderBalance({
    required this.id,
    required this.name,
    required this.received,
    required this.spent,
    required this.transferredIn,
    required this.transferredOut,
  });

  final String id;
  final String name;
  final double received;
  final double spent;
  final double transferredIn;
  final double transferredOut;

  /// Liquid cash this person should be holding right now.
  /// Negative = they paid from their own pocket and the fund owes them.
  double get balance => received + transferredIn - spent - transferredOut;
}

class EventLedger {
  const EventLedger({
    required this.collected,
    required this.spent,
    required this.holders,
    required this.byCategory,
    required this.contributorCount,
  });

  final double collected;
  final double spent;
  final List<HolderBalance> holders;
  final Map<ExpenseCategory, double> byCategory;
  final int contributorCount;

  double get balance => collected - spent;

  factory EventLedger.compute({
    required List<Contribution> contributions,
    required List<EventExpense> expenses,
    required List<CashTransfer> transfers,
  }) {
    final acc = <String, _Acc>{};
    _Acc of(String id, String name) => acc.putIfAbsent(id, () => _Acc(id, name));

    var collected = 0.0;
    var spent = 0.0;
    final byCategory = <ExpenseCategory, double>{};

    for (final c in contributions) {
      collected += c.amount;
      of(c.holderId, c.holderName).received += c.amount;
    }
    for (final e in expenses) {
      spent += e.amount;
      of(e.paidById, e.paidByName).spent += e.amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    for (final t in transfers) {
      of(t.fromId, t.fromName).out += t.amount;
      of(t.toId, t.toName).inn += t.amount;
    }

    final holders = acc.values
        .map((a) => HolderBalance(
              id: a.id,
              name: a.name,
              received: a.received,
              spent: a.spent,
              transferredIn: a.inn,
              transferredOut: a.out,
            ))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    return EventLedger(
      collected: collected,
      spent: spent,
      holders: holders,
      byCategory: byCategory,
      contributorCount: contributions.map((c) => c.memberId).toSet().length,
    );
  }
}

class _Acc {
  _Acc(this.id, this.name);
  final String id;
  final String name;
  double received = 0;
  double spent = 0;
  double inn = 0;
  double out = 0;
}
