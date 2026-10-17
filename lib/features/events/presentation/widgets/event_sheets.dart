import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../kuri/domain/entities/member.dart';
import '../../../kuri/presentation/providers/kuri_providers.dart';
import '../../domain/entities/event_models.dart';
import '../providers/events_providers.dart';
import 'expense_style.dart';
import 'member_dropdown.dart';

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => child,
    );

Future<void> showCreateEventSheet(BuildContext context) => _sheet(context, const CreateEventSheet());
Future<void> showContributionSheet(BuildContext context, EventFund event) =>
    _sheet(context, ContributionSheet(event: event));
Future<void> showExpenseSheet(BuildContext context, EventFund event, {int defaultSplit = 1}) =>
    _sheet(context, ExpenseSheet(event: event, defaultSplit: defaultSplit));
Future<void> showTransferSheet(BuildContext context, EventFund event) =>
    _sheet(context, TransferSheet(event: event));

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.formKey, required this.children});

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

String? _amountValidator(String? v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount' : null;

InputDecoration _amountDecoration(String label) => InputDecoration(
      labelText: label,
      prefixText: '${AppConstants.currencySymbol} ',
      prefixIcon: const Icon(Icons.payments_rounded),
    );

void _fireAndForget(BuildContext context, Future<void> op, String failMsg) {
  final messenger = ScaffoldMessenger.of(context);
  op.catchError((Object e) {
    messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
  });
  Navigator.of(context).pop();
}

List<Member> _activeMembers(WidgetRef ref) =>
    (ref.watch(membersProvider).valueOrNull ?? const <Member>[]).where((m) => m.isActive).toList();

Member _byId(List<Member> list, String id) => list.firstWhere((m) => m.id == id);

// ───────────────────────────── Create event ─────────────────────────────
class CreateEventSheet extends ConsumerStatefulWidget {
  const CreateEventSheet({super.key});

  @override
  ConsumerState<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<CreateEventSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _perHead = TextEditingController();
  final _desc = TextEditingController();
  EventCategory _category = EventCategory.trip;

  @override
  void dispose() {
    _title.dispose();
    _perHead.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    _fireAndForget(
      context,
      ref.read(eventsRepositoryProvider).createEvent(
            title: _title.text,
            category: _category,
            perHeadTarget: double.tryParse(_perHead.text) ?? 0,
            description: _desc.text,
            byUid: uid,
          ),
      'Could not create fund',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'New event fund',
      formKey: _form,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in EventCategory.values)
              ChoiceChip(
                label: Text('${c.emoji}  ${c.label}'),
                selected: c == _category,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Title (e.g. Munnar Trip 2026)', prefixIcon: Icon(Icons.flag_rounded)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _perHead,
          keyboardType: TextInputType.number,
          decoration: _amountDecoration('Per-head contribution (optional)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _desc,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 20),
        GoldButton(label: 'CREATE FUND', icon: Icons.add_rounded, expand: true, onPressed: _save),
      ],
    );
  }
}

// ───────────────────────────── Contribution ─────────────────────────────
class ContributionSheet extends ConsumerStatefulWidget {
  const ContributionSheet({super.key, required this.event});

  final EventFund event;

  @override
  ConsumerState<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<ContributionSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.event.perHeadTarget > 0 ? widget.event.perHeadTarget.toStringAsFixed(0) : '',
  );
  final _note = TextEditingController();
  String? _memberId;
  String? _holderId;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save(List<Member> members) {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final member = _byId(members, _memberId!);
    final holder = _byId(members, _holderId!);
    _fireAndForget(
      context,
      ref.read(eventsRepositoryProvider).addContribution(
            eventId: widget.event.id,
            memberId: member.id,
            memberName: member.name,
            amount: double.parse(_amount.text),
            holderId: holder.id,
            holderName: holder.name,
            note: _note.text,
            byUid: uid,
          ),
      'Could not save contribution',
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _activeMembers(ref);
    return _SheetFrame(
      title: 'Add contribution',
      formKey: _form,
      children: [
        MemberDropdown(
          label: 'Paid by member',
          members: members,
          value: _memberId,
          onChanged: (v) => setState(() => _memberId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: _amountDecoration('Amount'),
          validator: _amountValidator,
        ),
        const SizedBox(height: 12),
        MemberDropdown(
          label: 'Cash received & held by',
          icon: Icons.account_balance_wallet_rounded,
          members: members,
          value: _holderId,
          onChanged: (v) => setState(() => _holderId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 20),
        GoldButton(label: 'SAVE CONTRIBUTION', icon: Icons.check_rounded, expand: true, onPressed: () => _save(members)),
      ],
    );
  }
}

// ───────────────────────────── Expense ─────────────────────────────
class ExpenseSheet extends ConsumerStatefulWidget {
  const ExpenseSheet({super.key, required this.event, this.defaultSplit = 1});

  final EventFund event;
  final int defaultSplit;

  @override
  ConsumerState<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<ExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.transport;
  String? _paidById;
  late int _split = widget.defaultSplit < 1 ? 1 : widget.defaultSplit;
  XFile? _receipt;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (file != null && mounted) setState(() => _receipt = file);
  }

  Future<void> _save(List<Member> members) async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final payer = _byId(members, _paidById!);
    final op = ref.read(eventsRepositoryProvider).addExpense(
          eventId: widget.event.id,
          category: _category,
          amount: double.parse(_amount.text),
          paidById: payer.id,
          paidByName: payer.name,
          description: _desc.text.trim().isEmpty ? _category.label : _desc.text,
          splitCount: _split,
          receiptFilePath: _receipt?.path,
          byUid: uid,
        );

    if (_receipt == null) {
      _fireAndForget(context, op, 'Could not save expense');
      return;
    }
    // With a receipt we must wait for the upload (needs network).
    setState(() => _saving = true);
    try {
      await op;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _activeMembers(ref);
    final amount = double.tryParse(_amount.text) ?? 0;
    final theme = Theme.of(context);
    return _SheetFrame(
      title: 'Log expense',
      formKey: _form,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ExpenseCategory.values)
              ChoiceChip(
                avatar: Icon(c.icon, size: 18, color: c.color),
                label: Text(c.label),
                selected: c == _category,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: _amountDecoration('Amount'),
          validator: _amountValidator,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        MemberDropdown(
          label: 'Paid from cash held by',
          icon: Icons.account_balance_wallet_rounded,
          members: members,
          value: _paidById,
          onChanged: (v) => setState(() => _paidById = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _desc,
          decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Split between', style: theme.textTheme.titleSmall),
                  Text(
                    amount > 0 ? '${formatMoney(amount / _split)} per head' : 'Per-head share',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: _split > 1 ? () => setState(() => _split--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text('$_split', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            ),
            IconButton.filledTonal(
              onPressed: _split < AppConstants.maxMembers ? () => setState(() => _split++) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_receipt != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(_receipt!.path), height: 140, width: double.infinity, fit: BoxFit.cover),
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
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Receipt photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('From gallery'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        GoldButton(
          label: _saving ? 'UPLOADING…' : 'SAVE EXPENSE',
          icon: Icons.check_rounded,
          loading: _saving,
          expand: true,
          onPressed: () => _save(members),
        ),
      ],
    );
  }
}

// ───────────────────────────── Cash handover ─────────────────────────────
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key, required this.event});

  final EventFund event;

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  String? _toId;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save(List<Member> members) {
    if (!_form.currentState!.validate()) return;
    if (_fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose two different people')));
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final from = _byId(members, _fromId!);
    final to = _byId(members, _toId!);
    _fireAndForget(
      context,
      ref.read(eventsRepositoryProvider).addTransfer(
            eventId: widget.event.id,
            fromId: from.id,
            fromName: from.name,
            toId: to.id,
            toName: to.name,
            amount: double.parse(_amount.text),
            note: _note.text,
            byUid: uid,
          ),
      'Could not save handover',
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _activeMembers(ref);
    return _SheetFrame(
      title: 'Cash handover',
      formKey: _form,
      children: [
        MemberDropdown(
          label: 'From (gives cash)',
          icon: Icons.north_east_rounded,
          members: members,
          value: _fromId,
          onChanged: (v) => setState(() => _fromId = v),
        ),
        const SizedBox(height: 12),
        MemberDropdown(
          label: 'To (receives cash)',
          icon: Icons.south_west_rounded,
          members: members,
          value: _toId,
          onChanged: (v) => setState(() => _toId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: _amountDecoration('Amount'),
          validator: _amountValidator,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 20),
        GoldButton(label: 'RECORD HANDOVER', icon: Icons.swap_horiz_rounded, expand: true, onPressed: () => _save(members)),
      ],
    );
  }
}
