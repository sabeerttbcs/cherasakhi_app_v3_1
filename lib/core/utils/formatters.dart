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

String formatDate(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM yyyy').format(d);

String formatDateTime(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM, h:mm a').format(d);

/// Normalises any typed number to E.164 (`+919876543210`), which is also the
/// format used for all stored phone numbers and the derived login alias.
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

/// Returns the international digits used by WhatsApp's `wa.me` URL.
///
/// A bare 10-digit number is treated as Indian because CheraSakhi's default
/// country is India. A number with `+`, `00`, or an already-entered country
/// code is otherwise preserved; the country code is never added twice.
String whatsappDigits(String raw) {
  final normalized = normalizePhone(raw);
  return normalized.startsWith('+')
      ? normalized.substring(1)
      : normalized.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Validates the number formats accepted by CheraSakhi invitations.
bool isValidPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final explicitInternational = trimmed.startsWith('+') ||
      trimmed.replaceAll(RegExp(r'[^0-9]'), '').startsWith('00');
  final digits = whatsappDigits(trimmed);
  if (digits.length < 8 || digits.length > 15) return false;
  if (explicitInternational) return true;
  final compact = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return compact.length == 10 ||
      (compact.length == 11 && compact.startsWith('0')) ||
      compact.length >= 11;
}

/// Stable Firebase Email/Password alias for a phone-number login.
/// The phone remains the visible username; the alias is never shown to users.
String phoneLoginAlias(String raw) {
  final phone = normalizePhone(raw);
  final digits = phone.replaceAll('+', '');
  return '$digits@members.sakhi.sabeerlabs.com';
}

String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
