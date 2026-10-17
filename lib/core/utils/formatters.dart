import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final NumberFormat _money = NumberFormat.currency(
  locale: AppConstants.currencyLocale,
  symbol: AppConstants.currencySymbol,
  decimalDigits: 0,
);

final NumberFormat _compact = NumberFormat.compactCurrency(
  locale: AppConstants.currencyLocale,
  symbol: AppConstants.currencySymbol,
  decimalDigits: 1,
);

String formatMoney(num value) => _money.format(value);

String formatMoneyCompact(num value) =>
    value.abs() < 100000 ? _money.format(value) : _compact.format(value);

String formatDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);

String formatDateTime(DateTime? d) => d == null ? '—' : DateFormat('d MMM, h:mm a').format(d);

/// Normalises any typed number to E.164 (`+919876543210`), which is also the
/// format Firebase Phone Auth puts into `request.auth.token.phone_number`.
String normalizePhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.startsWith('+')) {
    return '+${cleaned.substring(1).replaceAll('+', '')}';
  }
  final digits = cleaned.replaceAll('+', '');
  if (digits.startsWith('00')) return '+${digits.substring(2)}';
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+${AppConstants.defaultCountryCode}${digits.substring(1)}';
  }
  if (digits.length == 10) return '+${AppConstants.defaultCountryCode}$digits';
  return '+$digits';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
