import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/quiz_models.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../providers/quiz_providers.dart';
import '../widgets/quiz_format.dart';

enum _TimingMode { window, duration }

const _categoryPresets = [
  'ഇസ്ലാമിക് ക്വിസ് മത്സരം',
  'Weekly Knowledge Quest',
  'General Knowledge',
  'Kerala & Culture',
];

const _durationPresets = [5, 10, 15, 20, 30, 45, 60];

/// Admin: create or edit (before start) a scheduled live quiz.
class QuizSchedulerScreen extends ConsumerStatefulWidget {
  const QuizSchedulerScreen({super.key, this.existing});

  final QuizContest? existing;

  @override
  ConsumerState<QuizSchedulerScreen> createState() => _QuizSchedulerScreenState();
}

class _QuizSchedulerScreenState extends ConsumerState<QuizSchedulerScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _category = TextEditingController(text: _categoryPresets.first);
  final _question = TextEditingController();
  final _answer = TextEditingController();
  final _accepted = TextEditingController();
  final _customMinutes = TextEditingController();
  final List<TextEditingController> _options = [TextEditingController(), TextEditingController()];

  AnswerMode _mode = AnswerMode.options;
  int? _correctOption;
  _TimingMode _timing = _TimingMode.duration;
  late DateTime _start;
  late DateTime _end;
  int _durationMin = 30;
  bool _saving = false;
  bool _loadingExisting = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Next quarter hour, at least 15 minutes away.
    final base = now.add(const Duration(minutes: 15));
    _start = DateTime(base.year, base.month, base.day, base.hour, (base.minute ~/ 15 + 1) * 15);
    _end = _start.add(Duration(minutes: _durationMin));
    if (_editing) _loadExisting(widget.existing!);
  }

  Future<void> _loadExisting(QuizContest c) async {
    setState(() => _loadingExisting = true);
    _title.text = c.title;
    _category.text = c.category;
    _start = c.startTime;
    _end = c.endTime;
    _durationMin = c.duration.inMinutes;
    _timing = _TimingMode.window;
    try {
      final repo = ref.read(quizRepositoryProvider);
      final q = await repo.fetchQuestion(c.id);
      final secret = await repo.fetchSecret(c.id);
      if (!mounted) return;
      setState(() {
        _question.text = q.text;
        _mode = q.mode;
        _answer.text = secret.answer;
        _accepted.text = secret.acceptedAnswers.join(', ');
        if (q.options.isNotEmpty) {
          for (final ctl in _options) {
            ctl.dispose();
          }
          _options
            ..clear()
            ..addAll(q.options.map((o) => TextEditingController(text: o)));
          _correctOption = q.options.indexWhere((o) => o.trim() == secret.answer.trim());
          if (_correctOption! < 0) _correctOption = null;
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load quiz: $e')));
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _category, _question, _answer, _accepted, _customMinutes, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _effectiveEnd => _timing == _TimingMode.window ? _end : _start.add(Duration(minutes: _durationMin));

  // ───────────────────────── pickers ─────────────────────────

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Quiz date',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Quiz time',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_start);
    if (picked == null) return;
    setState(() {
      final length = _end.difference(_start);
      _start = picked;
      // Keep the same length when moving the start in window mode.
      if (_timing == _TimingMode.window) _end = picked.add(length.isNegative ? const Duration(minutes: 30) : length);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_end);
    if (picked != null) setState(() => _end = picked);
  }

  // ───────────────────────── save ─────────────────────────

  String? _validateSchedule() {
    final end = _effectiveEnd;
    if (_start.isBefore(DateTime.now().add(const Duration(minutes: 2)))) {
      return 'Start time must be at least 2 minutes from now.';
    }
    if (!end.isAfter(_start)) return 'End time must be after the start time.';
    if (end.difference(_start) < const Duration(minutes: 1)) return 'The quiz must run for at least 1 minute.';
    if (end.difference(_start) > const Duration(hours: 24)) return 'The quiz can run for at most 24 hours.';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final scheduleError = _validateSchedule();
    if (scheduleError != null) {
      messenger.showSnackBar(SnackBar(content: Text(scheduleError)));
      return;
    }
    final options = _mode == AnswerMode.options ? _options.map((c) => c.text.trim()).toList() : const <String>[];
    if (_mode == AnswerMode.options) {
      if (options.where((o) => o.isNotEmpty).length < 2) {
        messenger.showSnackBar(const SnackBar(content: Text('Add at least two options.')));
        return;
      }
      if (_correctOption == null || options[_correctOption!].isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Tap the circle next to the correct option.')));
        return;
      }
    }
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null || !user.canManageQuiz) return;

    final draft = QuizDraft(
      title: _title.text,
      category: _category.text,
      questionText: _question.text,
      options: options,
      answer: _mode == AnswerMode.options ? options[_correctOption!] : _answer.text,
      acceptedAnswers: _mode == AnswerMode.options
          ? const []
          : _accepted.text.split(RegExp(r'[,\n]')).map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      startTime: _start,
      endTime: _effectiveEnd,
    );

    setState(() => _saving = true);
    try {
      await ref.read(quizRepositoryProvider).scheduleContest(
            quizId: widget.existing?.id,
            draft: draft,
            adminUid: user.uid,
          );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Quiz scheduled for ${formatSchedule(_start)} 🎯'),
      ));
      Navigator.of(context).pop();
    } on QuizPermissionDenied {
      messenger.showSnackBar(const SnackBar(content: Text('Not allowed — a quiz cannot be changed after it starts.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit quiz' : 'Schedule live quiz')),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                children: [
                  const SectionHeader('Contest'),
                  TextFormField(
                    controller: _title,
                    style: quizTextStyle(size: 16),
                    decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.emoji_events_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _categoryPresets)
                        ChoiceChip(
                          label: Text(c, style: quizTextStyle(size: 13, height: 1.3)),
                          selected: _category.text == c,
                          onSelected: (_) => setState(() => _category.text = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _category,
                    style: quizTextStyle(size: 15),
                    decoration: const InputDecoration(labelText: 'Category (or type your own)', prefixIcon: Icon(Icons.label_rounded)),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SectionHeader('Question'),
                  TextFormField(
                    controller: _question,
                    minLines: 2,
                    maxLines: 6,
                    style: quizTextStyle(size: 17),
                    decoration: const InputDecoration(labelText: 'Question text (Malayalam or English)', alignLabelWithHint: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the question text' : null,
                  ),

                  const SectionHeader('Answer key', subtitle: 'Sealed and hidden from members until the end time'),
                  SegmentedButton<AnswerMode>(
                    segments: const [
                      ButtonSegment(value: AnswerMode.options, icon: Icon(Icons.radio_button_checked_rounded), label: Text('Multiple choice')),
                      ButtonSegment(value: AnswerMode.text, icon: Icon(Icons.keyboard_rounded), label: Text('Typed answer')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == AnswerMode.options) ..._optionEditors() else ..._textAnswerEditors(),

                  const SectionHeader('Timing'),
                  SegmentedButton<_TimingMode>(
                    segments: const [
                      ButtonSegment(value: _TimingMode.duration, icon: Icon(Icons.timer_rounded), label: Text('Start + duration')),
                      ButtonSegment(value: _TimingMode.window, icon: Icon(Icons.date_range_rounded), label: Text('Start & end time')),
                    ],
                    selected: {_timing},
                    onSelectionChanged: (s) => setState(() {
                      _timing = s.first;
                      if (_timing == _TimingMode.window) _end = _start.add(Duration(minutes: _durationMin));
                    }),
                  ),
                  const SizedBox(height: 12),
                  _DateTimeTile(label: 'Starts', value: _start, icon: Icons.play_circle_rounded, onTap: _pickStart),
                  const SizedBox(height: 8),
                  if (_timing == _TimingMode.window)
                    _DateTimeTile(label: 'Ends', value: _end, icon: Icons.stop_circle_rounded, onTap: _pickEnd)
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _durationPresets)
                          ChoiceChip(
                            label: Text('$m min'),
                            selected: _durationMin == m,
                            onSelected: (_) => setState(() {
                              _durationMin = m;
                              _customMinutes.clear();
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customMinutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Custom duration (minutes)', prefixIcon: Icon(Icons.edit_calendar_rounded)),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) setState(() => _durationMin = n);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _summary(theme),
                  const SizedBox(height: 22),
                  GoldButton(
                    label: _saving ? 'SAVING…' : (_editing ? 'SAVE CHANGES' : 'SCHEDULE QUIZ'),
                    icon: Icons.event_available_rounded,
                    loading: _saving,
                    expand: true,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _optionEditors() => [
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mark as correct',
                  onPressed: () => setState(() => _correctOption = i),
                  icon: Icon(
                    _correctOption == i ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: _correctOption == i ? const Color(0xFF059669) : AppColors.roseGold,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _options[i],
                    style: quizTextStyle(size: 16),
                    decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}'),
                  ),
                ),
                if (_options.length > 2)
                  IconButton(
                    tooltip: 'Remove option',
                    onPressed: () => setState(() {
                      _options.removeAt(i).dispose();
                      if (_correctOption == i) {
                        _correctOption = null;
                      } else if (_correctOption != null && _correctOption! > i) {
                        _correctOption = _correctOption! - 1;
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
              ],
            ),
          ),
        if (_options.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _options.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
            ),
          ),
      ];

  List<Widget> _textAnswerEditors() => [
        TextFormField(
          controller: _answer,
          style: quizTextStyle(size: 16, weight: FontWeight.w600),
          decoration: const InputDecoration(labelText: 'Correct answer', prefixIcon: Icon(Icons.key_rounded)),
          validator: (v) => (_mode == AnswerMode.text && (v == null || v.trim().isEmpty)) ? 'Enter the correct answer' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _accepted,
          style: quizTextStyle(size: 15),
          decoration: const InputDecoration(
            labelText: 'Also accept (optional)',
            helperText: 'Other spellings, separated by commas, e.g. Makkah, Mecca, മക്ക',
            prefixIcon: Icon(Icons.spellcheck_rounded),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Matching ignores capitals, extra spaces, punctuation and old/new Malayalam chillu spellings.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];

  Widget _summary(ThemeData theme) {
    final end = _effectiveEnd;
    final minutes = end.difference(_start).inMinutes;
    final error = _validateSchedule();
    return GlassCard(
      blur: false,
      color: error == null ? AppColors.blush : const Color(0xFFFFF1F2),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.berry),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${formatSchedule(_start)} → ${formatClock(end)}  ($minutes min)',
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.berry),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error ??
                '🔒 The question unlocks at ${formatClock(_start)}. The answer is sealed with SHA-256 and '
                    'revealed only at ${formatClock(end)}. The quiz always runs the full time.',
            style: theme.textTheme.bodySmall?.copyWith(color: error == null ? AppColors.berry : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final DateTime value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.roseGold),
          const SizedBox(width: 12),
          SizedBox(width: 56, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(child: Text(formatSchedule(value), style: Theme.of(context).textTheme.titleSmall)),
          const Icon(Icons.edit_calendar_rounded, size: 20),
        ],
      ),
    );
  }
}
