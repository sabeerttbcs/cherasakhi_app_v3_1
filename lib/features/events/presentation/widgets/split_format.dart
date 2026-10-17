import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/split/split_engine.dart';

final NumberFormat _exact = NumberFormat.currency(
  locale: AppConstants.currencyLocale,
  symbol: AppConstants.currencySymbol,
  decimalDigits: 2,
);

/// ₹1,000 · or ₹952.38 when [exact] and there are paise.
String formatPaise(num paise, {bool exact = false}) {
  final rounded = paise.round();
  if (exact && rounded % 100 != 0) return _exact.format(rounded / 100);
  return formatMoney((rounded / 100).round());
}

class NetStatusStyle {
  const NetStatusStyle(this.color, this.background, this.icon, this.malayalam, this.english);

  final Color color;
  final Color background;
  final IconData icon;
  final String malayalam;
  final String english;

  static NetStatusStyle of(NetStatus s) => switch (s) {
        NetStatus.getsBack => const NetStatusStyle(
            Color(0xFF047857), Color(0xFFD1FAE5), Icons.south_west_rounded, 'തിരികെ ലഭിക്കണം', 'Gets back'),
        NetStatus.owes => const NetStatusStyle(
            Color(0xFFB91C1C), Color(0xFFFEE2E2), Icons.north_east_rounded, 'നൽകാൻ ബാക്കി', 'Owes'),
        NetStatus.settled => const NetStatusStyle(
            Color(0xFF4B5563), Color(0xFFE5E7EB), Icons.check_circle_rounded, 'തീർപ്പാക്കി', 'Settled'),
      };

  /// "Gets back ₹19,000" / "Owes ₹952" / "Settled"
  String englishLabel(int netPaise) =>
      netPaise.abs() < settledThresholdPaise ? english : '$english ${formatPaise(netPaise.abs())}';
}
