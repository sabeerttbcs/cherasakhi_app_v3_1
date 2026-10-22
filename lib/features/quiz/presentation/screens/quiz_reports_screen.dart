import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/profile_menu_button.dart';
import '../../data/quiz_report_repository.dart';
import '../../domain/entities/quiz_report_models.dart';
import '../providers/quiz_providers.dart';
import '../quiz_report_pdf.dart';

class QuizReportsScreen extends ConsumerStatefulWidget {
  const QuizReportsScreen({super.key});

  @override
  ConsumerState<QuizReportsScreen> createState() => _QuizReportsScreenState();
}

class _QuizReportsScreenState extends ConsumerState<QuizReportsScreen> {
  QuizReportKind _kind = QuizReportKind.weekly;
  QuizCategoryFilter _category = QuizCategoryFilter.all;
  int _offset = 0;
  DateTime? _customStart;
  DateTime? _customEnd;
  QuizReport? _report;
  QuizPrizeSelection? _prize;
  PrizeCriterion _prizeCriterion = PrizeCriterion.mostCorrect;
  String? _selectedPrizeUid;
  String? _error;
  bool _loading = false;
  bool _exporting = false;
  int _congratulationCount = 0;
  bool _hasCongratulated = false;
  int _request = 0;
  final TextEditingController _photoController = TextEditingController();

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  QuizReportPeriod get _period {
    if (_kind == QuizReportKind.custom &&
        _customStart != null &&
        _customEnd != null) {
      return QuizReportPeriod.custom(_customStart!, _customEnd!);
    }
    return QuizReportPeriod.current(_kind).shift(_offset);
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await ref.read(quizReportRepositoryProvider).loadReport(
            period: _period,
            category: _category,
            includeAllMembers: ref.read(isAdminProvider),
          );
      QuizPrizeSelection? prize;
      var congratulationCount = 0;
      var hasCongratulated = false;
      if (_kind == QuizReportKind.monthly) {
        final repo = ref.read(quizReportRepositoryProvider);
        prize = await repo.fetchPrize(_period.monthKey);
        final uid = ref.read(currentUidProvider);
        if (prize != null && uid != null) {
          final values = await Future.wait([
            repo.fetchCongratulationCount(prize.monthKey),
            repo.hasCongratulated(monthKey: prize.monthKey, uid: uid),
          ]);
          congratulationCount = values[0] as int;
          hasCongratulated = values[1] as bool;
        }
      }
      if (!mounted || request != _request) return;
      setState(() {
        _report = report;
        _prize = prize;
        _prizeCriterion = prize?.criterion ?? PrizeCriterion.mostCorrect;
        _selectedPrizeUid = prize?.recipientUid;
        _photoController.text = prize?.photoUrl ?? '';
        _congratulationCount = congratulationCount;
        _hasCongratulated = hasCongratulated;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the report: $e';
      });
    }
  }

  Future<void> _chooseCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(
              start: _customStart!,
              end: _customEnd!.subtract(const Duration(days: 1)))
          : DateTimeRange(
              start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked == null) return;
    setState(() {
      _kind = QuizReportKind.custom;
      _offset = 0;
      _customStart =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day)
          .add(const Duration(days: 1));
    });
    await _load();
  }

  void _setKind(QuizReportKind value) {
    setState(() {
      _kind = value;
      _offset = 0;
      _customStart = null;
      _customEnd = null;
    });
    _load();
  }

  void _setCategory(QuizCategoryFilter value) {
    setState(() => _category = value);
    _load();
  }

  void _shift(int amount) {
    if (_kind == QuizReportKind.custom) return;
    setState(() => _offset += amount);
    _load();
  }

  Future<void> _downloadPdf() async {
    final report = _report;
    if (report == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await QuizReportPdf.download(report, prize: _prize);
      if (mounted) _snack('PDF report ready to save or share.');
    } catch (e) {
      if (mounted) _snack('Could not generate PDF report: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmPrize() async {
    final report = _report;
    if (report == null) return;
    final candidates = report.candidatesFor(_prizeCriterion);
    if (candidates.isEmpty) {
      _snack('No eligible candidate for this criterion.');
      return;
    }
    final uid = _selectedPrizeUid ?? candidates.first.userId;
    final selected = candidates.firstWhere(
        (candidate) => candidate.userId == uid,
        orElse: () => candidates.first);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm monthly prize'),
        content: Text(
            '${_prizeCriterion.label}\n\nRecipient: ${selected.name}\n\nNo payment or finance transaction will be created.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('CANCEL')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('CONFIRM')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(quizReportRepositoryProvider).confirmPrize(
            period: _period,
            criterion: _prizeCriterion,
            recipient: selected,
            photoUrl: isConsentPhotoUrl(_photoController.text)
                ? _photoController.text.trim()
                : '',
          );
      if (mounted) {
        _snack('Monthly prize recipient confirmed.');
        await _load();
      }
    } catch (e) {
      if (mounted) _snack('Could not confirm prize: $e');
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Leaderboard & Reports'),
        actions: const [
          Padding(
              padding: EdgeInsets.only(right: 12), child: ProfileMenuButton())
        ],
      ),
      body: AmbientBackground(
        child: RefreshIndicator(
          color: AppColors.berry,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _filters(context),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (!_loading && _report != null) ...[
                if (_prize != null) ...[
                  _championCard(context, _prize!),
                  const SizedBox(height: 12),
                ],
                _summary(context, _report!),
                const SizedBox(height: 12),
                if (_report!.warnings.isNotEmpty) _warnings(_report!),
                const SizedBox(height: 12),
                _winnerCards(context, _report!),
                const SizedBox(height: 12),
                _leaderboard(context, _report!, isAdmin),
                const SizedBox(height: 12),
                _dailyWinners(context, _report!),
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  _prizePanel(context, _report!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _downloadPdf,
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(
                        _exporting ? 'GENERATING PDF…' : 'DOWNLOAD PDF REPORT'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) => GlassCard(
        blur: false,
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<QuizReportKind>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Report period'),
              items: const [
                DropdownMenuItem(
                    value: QuizReportKind.daily, child: Text('Daily')),
                DropdownMenuItem(
                    value: QuizReportKind.weekly, child: Text('Weekly')),
                DropdownMenuItem(
                    value: QuizReportKind.monthly, child: Text('Monthly')),
                DropdownMenuItem(
                    value: QuizReportKind.custom,
                    child: Text('Custom date range')),
              ],
              onChanged: (value) {
                if (value == QuizReportKind.custom) {
                  _chooseCustomRange();
                } else if (value != null) {
                  _setKind(value);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<QuizCategoryFilter>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Quiz category'),
              items: [
                for (final category in QuizCategoryFilter.values)
                  DropdownMenuItem(
                      value: category, child: Text(category.label)),
              ],
              onChanged: (value) {
                if (value != null) _setCategory(value);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_kind != QuizReportKind.custom) ...[
                  IconButton(
                      tooltip: 'Previous period',
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(
                      child: Text(_period.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall)),
                  IconButton(
                      tooltip: 'Next period',
                      onPressed: _offset >= 0 ? null : () => _shift(1),
                      icon: const Icon(Icons.chevron_right_rounded)),
                ] else ...[
                  Expanded(
                      child: Text(_period.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall)),
                  TextButton.icon(
                      onPressed: _chooseCustomRange,
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('CHANGE')),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _summary(BuildContext context, QuizReport report) => GlassCard(
        blur: false,
        radius: 18,
        child: Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _metric(context, 'Completed', report.completedQuizCount),
            _metric(context, 'Participants', report.participatingMembers),
            _metric(context, 'Answers', report.totalAnswers),
            _metric(context, 'Correct', report.totalCorrect),
            _metric(context, 'Wrong', report.totalIncorrect),
          ],
        ),
      );

  Widget _metric(BuildContext context, String label, int value) => SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _warnings(QuizReport report) => GlassCard(
        blur: false,
        radius: 18,
        color: Colors.amber.withOpacity(0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Incomplete results are excluded'),
            for (final warning in report.warnings) Text('• $warning'),
          ],
        ),
      );

  Widget _winnerCards(BuildContext context, QuizReport report) {
    final correct = report.candidatesFor(PrizeCriterion.mostCorrect);
    final active = report.candidatesFor(PrizeCriterion.mostParticipation);
    final wins = report.candidatesFor(PrizeCriterion.mostDailyWins);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance leaders',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _leaderCard(context, 'Most Correct', correct),
            _leaderCard(context, 'Most Active', active),
            _leaderCard(context, 'Most Daily Wins', wins),
            _leaderCard(context, 'Best Accuracy', report.bestAccuracyCandidates,
                subtitle: 'Minimum $minimumAccuracyParticipation played'),
          ],
        ),
      ],
    );
  }

  Widget _leaderCard(BuildContext context, String label,
          List<QuizLeaderboardEntry> entries,
          {String? subtitle}) =>
      SizedBox(
        width: 180,
        child: GlassCard(
          blur: false,
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                  entries.isEmpty ? '—' : entries.map((e) => e.name).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _leaderboard(BuildContext context, QuizReport report, bool isAdmin) {
    final userId = ref.read(currentUidProvider);
    final own =
        report.leaderboard.where((entry) => entry.userId == userId).toList();
    return GlassCard(
      blur: false,
      radius: 18,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                  isAdmin ? 'Full member leaderboard' : 'Public leaderboard',
                  style: Theme.of(context).textTheme.titleLarge)),
          if (!isAdmin && own.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                    'Your result: #${own.first.rank} · ${own.first.correct} correct / ${own.first.participated} played')),
          if (report.leaderboard.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No participating members in this period.'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Rank')),
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Played')),
                  DataColumn(label: Text('Correct')),
                  DataColumn(label: Text('Wrong')),
                  DataColumn(label: Text('Wins')),
                  DataColumn(label: Text('Accuracy')),
                ],
                rows: [
                  for (final entry in report.leaderboard)
                    DataRow(cells: [
                      DataCell(Text('${entry.rank}')),
                      DataCell(Text(entry.name)),
                      DataCell(
                          Text('${entry.participated}/${entry.available}')),
                      DataCell(Text('${entry.correct}')),
                      DataCell(Text('${entry.incorrect}')),
                      DataCell(Text('${entry.dailyWins}')),
                      DataCell(
                          Text('${entry.accuracyPercent.toStringAsFixed(1)}%')),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dailyWinners(BuildContext context, QuizReport report) => GlassCard(
        blur: false,
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily winners',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (report.dailyWinners.isEmpty)
              const Text('No daily winners recorded.')
            else
              for (final winner in report.dailyWinners)
                Text(
                    '${winner.date.day}/${winner.date.month} · ${winner.name} · ${winner.title}'),
          ],
        ),
      );

  Widget _prizePanel(BuildContext context, QuizReport report) {
    if (_kind != QuizReportKind.monthly) {
      return const GlassCard(
          blur: false,
          radius: 18,
          child: Text('Select Monthly to confirm a prize recipient.'));
    }
    final candidates = report.candidatesFor(_prizeCriterion);
    _selectedPrizeUid ??= candidates.isEmpty ? null : candidates.first.userId;
    return GlassCard(
      blur: false,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monthly Prize Selection',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<PrizeCriterion>(
            value: _prizeCriterion,
            decoration: const InputDecoration(labelText: 'Award criterion'),
            items: [
              for (final criterion in PrizeCriterion.values)
                DropdownMenuItem(value: criterion, child: Text(criterion.label))
            ],
            onChanged: (value) => setState(() {
              _prizeCriterion = value ?? PrizeCriterion.mostCorrect;
              _selectedPrizeUid = null;
            }),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _photoController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Optional consented HTTPS photo URL',
              helperText:
                  'Public HTTPS URL only; leave blank for initials avatar.',
              prefixIcon: Icon(Icons.photo_camera_back_outlined),
            ),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            const Text('No eligible candidate.')
          else ...[
            const Text('Top candidate(s), including ties:'),
            for (final candidate in candidates)
              RadioListTile<String>(
                value: candidate.userId,
                groupValue: _selectedPrizeUid,
                onChanged: (value) => setState(() => _selectedPrizeUid = value),
                title: Text(candidate.name),
                subtitle: Text(
                    '#${candidate.rank} · ${candidate.correct} correct · ${candidate.participated} played'),
              ),
            FilledButton.icon(
                onPressed: _confirmPrize,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('CONFIRM PRIZE RECIPIENT')),
          ],
          if (_prize != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Confirmed: ${_prize!.recipientName} · ${_prize!.criterion.label}')),
        ],
      ),
    );
  }

  Widget _championCard(BuildContext context, QuizPrizeSelection prize) {
    final uid = ref.read(currentUidProvider);
    final photo = isConsentPhotoUrl(prize.photoUrl) ? prize.photoUrl : null;
    return GlassCard(
      blur: false,
      radius: 20,
      gradient: const LinearGradient(
        colors: [Color(0xFF7A1A4A), Color(0xFFB7791F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: photo == null ? null : NetworkImage(photo),
            onBackgroundImageError: photo == null ? null : (_, __) {},
            child: photo == null
                ? Text(championInitials(prize.recipientName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏆 Latest Monthly Champion',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(prize.recipientName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('${prize.monthKey} · ${prize.criterion.label}'),
                  Text(
                      'Congratulations! 🌸👏🏆  $_congratulationCount members'),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _hasCongratulated || uid == null
                        ? null
                        : () => _sendCongratulations(prize.monthKey, uid),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white54),
                    icon: Icon(_hasCongratulated
                        ? Icons.check_circle_outline
                        : Icons.celebration_outlined),
                    label: Text(_hasCongratulated
                        ? 'CONGRATULATIONS SENT'
                        : 'SEND CONGRATULATIONS'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCongratulations(String monthKey, String uid) async {
    try {
      await ref.read(quizReportRepositoryProvider).congratulate(
            monthKey: monthKey,
            uid: uid,
          );
      if (!mounted) return;
      setState(() {
        _hasCongratulated = true;
        _congratulationCount += 1;
      });
      _snack('Congratulations sent! 🌸👏🏆');
    } catch (e) {
      if (mounted) _snack('Could not send congratulations: $e');
    }
  }
}
