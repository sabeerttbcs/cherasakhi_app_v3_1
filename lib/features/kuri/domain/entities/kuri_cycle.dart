import '../../../../core/utils/month_key.dart';

enum CycleStatus { active, closed }

/// One full Kuri (chit) cycle — typically 60 months for 60 members.
class KuriCycle {
  const KuriCycle({
    required this.id,
    required this.name,
    required this.startMonth,
    required this.durationMonths,
    required this.monthlyInstallment,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String name;
  final String startMonth; // yyyy-MM
  final int durationMonths;
  final double monthlyInstallment;
  final CycleStatus status;
  final DateTime? createdAt;

  String get endMonth => MonthKey.add(startMonth, durationMonths - 1);
  List<String> get months => MonthKey.range(startMonth, durationMonths);

  bool contains(String monthKey) =>
      monthKey.compareTo(startMonth) >= 0 && monthKey.compareTo(endMonth) <= 0;

  String clamp(String monthKey) {
    if (monthKey.compareTo(startMonth) < 0) return startMonth;
    if (monthKey.compareTo(endMonth) > 0) return endMonth;
    return monthKey;
  }
}
