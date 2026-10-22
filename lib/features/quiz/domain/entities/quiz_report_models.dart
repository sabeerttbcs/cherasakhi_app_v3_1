const _indiaOffset = Duration(hours: 5, minutes: 30);

enum QuizReportKind { daily, weekly, monthly, custom }

enum QuizCategoryFilter { all, islamic, general }

enum PrizeCriterion { mostCorrect, mostParticipation, mostDailyWins }

const int minimumAccuracyParticipation = 2;

String championInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final values = parts.toList(growable: false);
  if (values.isEmpty) return 'CS';
  if (values.length == 1) {
    final value = values.first;
    return value.substring(0, value.length > 1 ? 2 : 1).toUpperCase();
  }
  return '${values.first[0]}${values.last[0]}'.toUpperCase();
}

bool isConsentPhotoUrl(String value) => value.trim().startsWith('https://');

String congratulationDocId(String monthKey, String uid) => '${monthKey}_$uid';

extension QuizCategoryFilterLabel on QuizCategoryFilter {
  String get label => switch (this) {
        QuizCategoryFilter.all => 'All categories',
        QuizCategoryFilter.islamic => 'Islamic Quiz',
        QuizCategoryFilter.general => 'General Knowledge Quiz',
      };
}

extension PrizeCriterionLabel on PrizeCriterion {
  String get label => switch (this) {
        PrizeCriterion.mostCorrect => 'Most Correct Answers',
        PrizeCriterion.mostParticipation => 'Most Participation',
        PrizeCriterion.mostDailyWins => 'Most Daily Wins',
      };

  String get firestoreValue => switch (this) {
        PrizeCriterion.mostCorrect => 'mostCorrect',
        PrizeCriterion.mostParticipation => 'mostParticipation',
        PrizeCriterion.mostDailyWins => 'mostDailyWins',
      };
}

/// A report range represented as UTC instants, with calendar boundaries in
/// Asia/Kolkata. This avoids depending on the device's local timezone.
class QuizReportPeriod {
  const QuizReportPeriod({
    required this.kind,
    required this.startUtc,
    required this.endUtc,
  });

  final QuizReportKind kind;
  final DateTime startUtc;
  final DateTime endUtc;

  DateTime get startIndia => startUtc.toUtc().add(_indiaOffset);
  DateTime get endIndia => endUtc.toUtc().add(_indiaOffset);

  String get monthKey =>
      '${startIndia.year.toString().padLeft(4, '0')}-${startIndia.month.toString().padLeft(2, '0')}';

  String get label {
    final start = _dateLabel(startIndia);
    final end = _dateLabel(endIndia.subtract(const Duration(days: 1)));
    return switch (kind) {
      QuizReportKind.daily => start,
      QuizReportKind.weekly => '$start – $end',
      QuizReportKind.monthly => '$start – $end',
      QuizReportKind.custom => '$start – $end',
    };
  }

  QuizReportPeriod shift(int amount) {
    if (kind == QuizReportKind.custom) return this;
    final startIndiaDate =
        DateTime.utc(startIndia.year, startIndia.month, startIndia.day);
    final shifted = switch (kind) {
      QuizReportKind.daily => startIndiaDate.add(Duration(days: amount)),
      QuizReportKind.weekly => startIndiaDate.add(Duration(days: amount * 7)),
      QuizReportKind.monthly =>
        DateTime.utc(startIndia.year, startIndia.month + amount, 1),
      QuizReportKind.custom => startIndiaDate,
    };
    return fromIndiaDates(
        kind,
        shifted,
        switch (kind) {
          QuizReportKind.daily => shifted.add(const Duration(days: 1)),
          QuizReportKind.weekly => shifted.add(const Duration(days: 7)),
          QuizReportKind.monthly =>
            DateTime.utc(shifted.year, shifted.month + 1, 1),
          QuizReportKind.custom => shifted.add(const Duration(days: 1)),
        });
  }

  static QuizReportPeriod current(QuizReportKind kind, {DateTime? nowUtc}) {
    final indiaNow =
        (nowUtc ?? DateTime.now().toUtc()).toUtc().add(_indiaOffset);
    final today = DateTime.utc(indiaNow.year, indiaNow.month, indiaNow.day);
    return switch (kind) {
      QuizReportKind.daily =>
        fromIndiaDates(kind, today, today.add(const Duration(days: 1))),
      QuizReportKind.weekly => _currentWeek(today),
      QuizReportKind.monthly => fromIndiaDates(
          kind,
          DateTime.utc(today.year, today.month, 1),
          DateTime.utc(today.year, today.month + 1, 1)),
      QuizReportKind.custom =>
        fromIndiaDates(kind, today, today.add(const Duration(days: 1))),
    };
  }

  static QuizReportPeriod custom(DateTime startIndia, DateTime endIndia) =>
      fromIndiaDates(
          QuizReportKind.custom, _dateOnly(startIndia), _dateOnly(endIndia));

  static QuizReportPeriod fromIndiaDates(
      QuizReportKind kind, DateTime startIndia, DateTime endIndia) {
    final start = _dateOnly(startIndia);
    final end = _dateOnly(endIndia);
    return QuizReportPeriod(
      kind: kind,
      startUtc: start.subtract(_indiaOffset).toUtc(),
      endUtc: end.subtract(_indiaOffset).toUtc(),
    );
  }

  static QuizReportPeriod _currentWeek(DateTime today) {
    final monday =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    return fromIndiaDates(
        QuizReportKind.weekly, monday, monday.add(const Duration(days: 7)));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

bool categoryMatches(String category, QuizCategoryFilter filter) {
  if (filter == QuizCategoryFilter.all) return true;
  final value = category.trim().toLowerCase();
  final islamic = value.contains('islam') || value.contains('ഇസ്ലാമ');
  final general = value.contains('general') ||
      value.contains('knowledge') ||
      value.contains('പൊതു') ||
      value.contains('അറിവ്');
  return filter == QuizCategoryFilter.islamic ? islamic : general && !islamic;
}

class QuizLeaderboardEntry {
  const QuizLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.available,
    required this.participated,
    required this.correct,
    required this.incorrect,
    required this.dailyWins,
  });

  final int rank;
  final String userId;
  final String name;
  final int available;
  final int participated;
  final int correct;
  final int incorrect;
  final int dailyWins;

  double get participationPercent =>
      available == 0 ? 0 : participated * 100 / available;
  double get accuracyPercent =>
      participated == 0 ? 0 : correct * 100 / participated;
}

class QuizDailyWinner {
  const QuizDailyWinner({
    required this.quizId,
    required this.title,
    required this.date,
    required this.userId,
    required this.name,
    required this.category,
  });

  final String quizId;
  final String title;
  final DateTime date;
  final String userId;
  final String name;
  final String category;
}

class QuizReport {
  const QuizReport({
    required this.period,
    required this.category,
    required this.completedQuizCount,
    required this.totalAnswers,
    required this.totalCorrect,
    required this.totalIncorrect,
    required this.leaderboard,
    required this.dailyWinners,
    required this.warnings,
  });

  final QuizReportPeriod period;
  final QuizCategoryFilter category;
  final int completedQuizCount;
  final int totalAnswers;
  final int totalCorrect;
  final int totalIncorrect;
  final List<QuizLeaderboardEntry> leaderboard;
  final List<QuizDailyWinner> dailyWinners;
  final List<String> warnings;

  int get participatingMembers =>
      leaderboard.where((e) => e.participated > 0).length;

  List<QuizLeaderboardEntry> candidatesFor(PrizeCriterion criterion) {
    final eligible =
        leaderboard.where((entry) => entry.participated > 0).toList();
    if (eligible.isEmpty) return const [];
    int score(QuizLeaderboardEntry entry) => switch (criterion) {
          PrizeCriterion.mostCorrect => entry.correct,
          PrizeCriterion.mostParticipation => entry.participated,
          PrizeCriterion.mostDailyWins => entry.dailyWins,
        };
    final top = eligible.map(score).reduce((a, b) => a > b ? a : b);
    return eligible
        .where((entry) => score(entry) == top)
        .toList(growable: false);
  }

  List<QuizLeaderboardEntry> get bestAccuracyCandidates {
    final eligible = leaderboard
        .where((entry) => entry.participated >= minimumAccuracyParticipation)
        .toList(growable: false);
    if (eligible.isEmpty) return const [];
    final top = eligible
        .map((entry) => entry.accuracyPercent)
        .reduce((a, b) => a > b ? a : b);
    return eligible
        .where((entry) => entry.accuracyPercent == top)
        .toList(growable: false);
  }
}
