import 'package:intl/intl.dart';

/// Months are stored as sortable `yyyy-MM` keys, e.g. `2026-10`.
class MonthKey {
  MonthKey._();

  static String fromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static String current() => fromDate(DateTime.now());

  static DateTime toDate(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String add(String key, int months) {
    final d = toDate(key);
    return fromDate(DateTime(d.year, d.month + months));
  }

  static int year(String key) => int.parse(key.substring(0, 4));

  static String label(String key) => DateFormat('MMMM yyyy').format(toDate(key));
  static String short(String key) => DateFormat('MMM').format(toDate(key));

  static List<String> range(String start, int count) =>
      List.generate(count, (i) => add(start, i), growable: false);
}
