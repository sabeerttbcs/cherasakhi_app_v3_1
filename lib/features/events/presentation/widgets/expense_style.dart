import 'package:flutter/material.dart';

import '../../domain/entities/event_models.dart';

extension ExpenseCategoryStyle on ExpenseCategory {
  IconData get icon => switch (this) {
        ExpenseCategory.transport => Icons.directions_bus_rounded,
        ExpenseCategory.dining => Icons.restaurant_rounded,
        ExpenseCategory.accommodation => Icons.hotel_rounded,
        ExpenseCategory.misc => Icons.category_rounded,
      };

  Color get color => switch (this) {
        ExpenseCategory.transport => const Color(0xFF0EA5E9),
        ExpenseCategory.dining => const Color(0xFFF59E0B),
        ExpenseCategory.accommodation => const Color(0xFF8B5CF6),
        ExpenseCategory.misc => const Color(0xFF64748B),
      };
}
