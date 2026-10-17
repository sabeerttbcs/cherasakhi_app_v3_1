import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../domain/entities/member.dart';
import '../providers/kuri_providers.dart';

Future<void> showMemberFormSheet(BuildContext context, {Member? member}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => MemberFormSheet(member: member),
  );
}

class MemberFormSheet extends ConsumerStatefulWidget {
  const MemberFormSheet({super.key, this.member});

  final Member? member;

  @override
  ConsumerState<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends ConsumerState<MemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _phone = TextEditingController(text: widget.member?.phone ?? '');
  late bool _active = widget.member?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final members = ref.read(membersProvider).valueOrNull ?? const <Member>[];
    final phone = normalizePhone(_phone.text);
    final repo = ref.read(kuriRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    final duplicate = members.any((m) => m.phone == phone && m.id != widget.member?.id);
    if (duplicate) {
      messenger.showSnackBar(const SnackBar(content: Text('Another member already uses this number')));
      return;
    }

    final Future<void> op;
    if (widget.member == null) {
      if (members.where((m) => m.isActive).length >= AppConstants.maxMembers) {
        messenger.showSnackBar(
            const SnackBar(content: Text('The collective is full (${AppConstants.maxMembers} members)')));
        return;
      }
      final nextSeat = members.fold<int>(0, (max, m) => m.seatNo > max ? m.seatNo : max) + 1;
      op = repo.addMember(name: _name.text, phone: phone, seatNo: nextSeat);
    } else {
      op = repo.updateMember(widget.member!.copyWith(name: _name.text.trim(), phone: phone, isActive: _active));
    }
    // Fire-and-forget: Firestore applies it locally at once (works offline).
    op.catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.member != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing ? 'Edit member' : 'Add member', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp / login number',
                helperText: '10 digits → +${AppConstants.defaultCountryCode} is added automatically',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              validator: (v) => normalizePhone(v ?? '').length < 11 ? 'Enter a valid number' : null,
            ),
            if (editing)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active member'),
                subtitle: const Text('Inactive members are excluded from collections & draws'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 20),
            GoldButton(label: editing ? 'SAVE CHANGES' : 'ADD MEMBER', icon: Icons.check_rounded, expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
