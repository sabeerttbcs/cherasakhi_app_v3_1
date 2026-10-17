import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/event_models.dart';
import '../../domain/split/trip_participant.dart';
import '../controllers/event_split_controller.dart';
import 'event_split_dashboard.dart';
import 'expense_style.dart';
import 'split_format.dart';

/// Quick titles → category.
const _quickBills = <(String, ExpenseCategory)>[
  ('Bus Rental', ExpenseCategory.transport),
  ('Fuel', ExpenseCategory.transport),
  ('Food & Tea', ExpenseCategory.dining),
  ('Lunch', ExpenseCategory.dining),
  ('Resort Stay', ExpenseCategory.accommodation),
  ('Entry Tickets', ExpenseCategory.misc),
];

/// Log a bill on the go. It is split across all current participants.
Future<void> showSplitExpenseSheet(BuildContext context, EventFund event) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SplitExpenseSheet(event: event),
    );

class SplitExpenseSheet extends ConsumerStatefulWidget {
  const SplitExpenseSheet({super.key, required this.event});

  final EventFund event;

  @override
  ConsumerState<SplitExpenseSheet> createState() => _SplitExpenseSheetState();
}

class _SplitExpenseSheetState extends ConsumerState<SplitExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.transport;
  String? _payerId;
  XFile? _receipt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default payer: me, if I'm on the trip.
    final me = participantIdFor(ref.read(appUserProvider).valueOrNull);
    final split = ref.read(eventSplitControllerProvider(widget.event.id));
    if (split.isListed(me)) _payerId = me;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (f != null && mounted) setState(() => _receipt = f);
  }

  Future<void> _save(List<TripParticipant> participants) async {
    if (!_form.currentState!.validate()) return;
    final payer = participants.firstWhere((p) => p.id == _payerId);
    final controller = ref.read(eventSplitControllerProvider(widget.event.id).notifier);
    final messenger = ScaffoldMessenger.of(context);
    final op = controller.addBill(
      title: _title.text.trim(),
      category: _category,
      amount: double.parse(_amount.text),
      paidBy: payer,
      receiptFilePath: _receipt?.path,
    );
    if (_receipt == null) {
      // Saved to the local cache instantly (works offline), synced later.
      op.catchError((Object e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not save bill: $e')));
      });
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await op;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final split = ref.watch(eventSplitControllerProvider(widget.event.id));
    final controller = ref.read(eventSplitControllerProvider(widget.event.id).notifier);
    final participants = sortedParticipants(split.participants);
    final amount = double.tryParse(_amount.text) ?? 0;
    final n = split.summary.activeCount;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add bill', style: theme.textTheme.titleLarge),
            Text('Split equally across all $n current participants', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (title, cat) in _quickBills)
                  ActionChip(
                    avatar: Icon(cat.icon, size: 16, color: cat.color),
                    label: Text(title),
                    onPressed: () => setState(() {
                      _title.text = title;
                      _category = cat;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What was it for?', prefixIcon: Icon(Icons.edit_note_rounded)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    label: Text(c.label),
                    selected: c == _category,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total amount',
                prefixText: '${AppConstants.currencySymbol} ',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter the amount' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: participants.any((p) => p.id == _payerId) ? _payerId : null,
              isExpanded: true,
              menuMaxHeight: 420,
              decoration: const InputDecoration(labelText: 'Paid by (from their pocket)', prefixIcon: Icon(Icons.person_pin_rounded)),
              items: [
                for (final p in participants)
                  DropdownMenuItem(value: p.id, child: Text(p.active ? p.name : '${p.name} (not sharing)')),
              ],
              validator: (v) => v == null ? (participants.isEmpty ? 'Add participants first' : 'Who paid?') : null,
              onChanged: (v) => setState(() => _payerId = v),
            ),
            const SizedBox(height: 12),
            if (amount > 0 && n > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.blush, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  '${formatPaise(amount * 100)} ÷ $n = ${formatPaise(amount * 100 / n, exact: true)} each.\n'
                  'New per-person share for the whole trip: '
                  '${formatPaise(controller.previewShareWith(amount), exact: true)}',
                  style: const TextStyle(color: AppColors.berry, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            const SizedBox(height: 12),
            if (_receipt != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(_receipt!.path, height: 140, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_receipt!.path), height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filled(
                      onPressed: () => setState(() => _receipt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Bill photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            GoldButton(
              label: _saving ? 'UPLOADING…' : 'SAVE & SPLIT',
              icon: Icons.call_split_rounded,
              loading: _saving,
              expand: true,
              onPressed: participants.isEmpty ? null : () => _save(participants),
            ),
          ],
        ),
      ),
    );
  }
}
