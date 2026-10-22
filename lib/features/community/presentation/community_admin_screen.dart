import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gold_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../domain/community_models.dart';
import 'contact_picker.dart';
import 'community_providers.dart';

/// Admin: invite-only access, community roster, and Kuri access.
class CommunityAdminScreen extends StatelessWidget {
  const CommunityAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community & access'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.mail_lock_rounded), text: 'Invitations'),
              Tab(icon: Icon(Icons.groups_rounded), text: 'Community roster'),
              Tab(icon: Icon(Icons.lock_person_rounded), text: 'Kuri access'),
            ],
          ),
        ),
        body: const TabBarView(
            children: [_InvitationsTab(), _RosterTab(), _AccessTab()]),
      ),
    );
  }
}

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(invitationsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create-invite',
        backgroundColor: AppColors.roseGold,
        foregroundColor: Colors.white,
        onPressed: () => _showInviteSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add member'),
      ),
      body: invitations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load invitations',
            message: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.mail_lock_rounded,
                title: 'No invitations yet',
                message:
                    'Create an invite to let a member create a password and sign in with their phone number.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _InvitationTile(invitation: list[i]),
              ),
      ),
    );
  }

  static void _showInviteSheet(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add member & create invite',
                  style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!contactPickerSupported) {
                    await _showContactFallback(sheet);
                    return;
                  }
                  final contact = await pickContact();
                  if (!sheet.mounted || contact == null) return;
                  if (contact.name.isNotEmpty) name.text = contact.name;
                  final phoneNumber =
                      await _choosePhoneNumber(sheet, contact.phoneNumbers);
                  if (phoneNumber != null) {
                    phone.text = normalizePhone(phoneNumber);
                  }
                },
                icon: const Icon(Icons.contacts_rounded),
                label: const Text('CHOOSE FROM CONTACTS'),
              ),
              const SizedBox(height: 8),
              Text(
                contactPickerSupported
                    ? 'Android Chrome can share one selected contact only.'
                    : 'On iPhone, tap a field and use Safari Contact AutoFill if it is offered. Otherwise paste the number below.',
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              AutofillGroup(
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_rounded)),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      onEditingComplete: () {
                        _normalisePhoneController(phone);
                        FocusScope.of(sheet).unfocus();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Phone / WhatsApp number',
                        helperText:
                            'Paste a number; it is normalized to E.164 when you continue.',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      validator: (v) => !isValidPhone(v ?? '')
                          ? 'Enter a valid international number'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: note,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes_rounded)),
                  maxLines: 2),
              const SizedBox(height: 8),
              Text(
                'Only the contact you choose is read. CheraSakhi never uploads or syncs your contacts.',
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              GoldButton(
                label: 'CREATE WHATSAPP INVITE',
                icon: Icons.send_rounded,
                expand: true,
                onPressed: () async {
                  _normalisePhoneController(phone);
                  if (!formKey.currentState!.validate()) return;
                  final confirmed = await _confirmInvite(
                    sheet,
                    name: name.text.trim(),
                    phone: normalizePhone(phone.text),
                    note: note.text.trim(),
                  );
                  if (!confirmed || !sheet.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final token = await ref
                        .read(communityRepositoryProvider)
                        .createInvitation(
                            name: name.text,
                            phone: phone.text,
                            note: note.text);
                    final invitation = Invitation(
                      token: token,
                      name: name.text.trim(),
                      phone: normalizePhone(phone.text),
                      status: 'pending',
                      note: note.text.trim(),
                      expiresAt: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (!sheet.mounted) return;
                    Navigator.of(sheet).pop();
                    if (context.mounted) {
                      await _showInvitationActions(context, ref, invitation);
                    }
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                        content: Text('Could not create invitation: $e')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _normalisePhoneController(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    final normalized = normalizePhone(value);
    if (!isValidPhone(value) || normalized == value) return;
    controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length));
  }

  static Future<String?> _choosePhoneNumber(
      BuildContext context, List<String> numbers) async {
    final choices =
        numbers.map(normalizePhone).where(isValidPhone).toSet().toList();
    if (choices.length <= 1) return choices.isEmpty ? null : choices.first;
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Choose a WhatsApp number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices
              .map((number) => ListTile(
                    leading: const Icon(Icons.phone_rounded),
                    title: Text(number),
                    onTap: () => Navigator.of(dialog).pop(number),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('CANCEL'))
        ],
      ),
    );
  }

  static Future<void> _showContactFallback(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Contact selection unavailable'),
          content: const Text(
            'This browser does not provide a direct contact picker. On iPhone Safari, tap Full name or Phone / WhatsApp number and choose a saved contact suggestion if Safari offers it. You can also paste the number; it will be normalized automatically.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('OK'))
          ],
        ),
      );

  static Future<bool> _confirmInvite(
    BuildContext context, {
    required String name,
    required String phone,
    required String note,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm member details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Full name', style: Theme.of(dialog).textTheme.labelMedium),
            Text(name),
            const SizedBox(height: 12),
            Text('WhatsApp number',
                style: Theme.of(dialog).textTheme.labelMedium),
            Text(phone),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Note', style: Theme.of(dialog).textTheme.labelMedium),
              Text(note),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('EDIT')),
          FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('CREATE INVITE')),
        ],
      ),
    );
    return result ?? false;
  }

  static String _invitationMessage(Invitation invitation) =>
      WhatsAppLauncher.invitationMessage(
          name: invitation.name, token: invitation.token);

  static Future<void> _showInvitationActions(
    BuildContext context,
    WidgetRef ref,
    Invitation invitation,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        title: const Text('Invitation Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved for ${invitation.name}.'),
            const SizedBox(height: 8),
            Text(invitation.phone,
                style: Theme.of(dialog).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
                'WhatsApp is not marked as sent. Open the chat and press Send yourself.'),
          ],
        ),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
            onPressed: () => _openWhatsApp(context, ref, invitation, dialog),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('OPEN WHATSAPP'),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyInvitation(context, invitation),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('COPY INVITATION'),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyPhone(context, invitation),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('COPY PHONE NUMBER'),
          ),
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('CLOSE')),
        ],
      ),
    );
  }

  static Future<void> _openWhatsApp(
    BuildContext context,
    WidgetRef ref,
    Invitation invitation,
    BuildContext dialog,
  ) async {
    final opened = await WhatsAppLauncher.openInvitation(
      phone: invitation.phone,
      message: _invitationMessage(invitation),
    );
    if (!context.mounted || opened) {
      if (opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('WhatsApp opened. Press Send to deliver it.')));
      }
      return;
    }
    if (dialog.mounted) Navigator.of(dialog).pop();
    if (context.mounted) {
      await _showWhatsAppError(context, ref, invitation);
    }
  }

  static Future<void> _openExistingInvitation(
    BuildContext context,
    WidgetRef ref,
    Invitation invitation,
  ) async {
    final opened = await WhatsAppLauncher.openInvitation(
      phone: invitation.phone,
      message: _invitationMessage(invitation),
    );
    if (!context.mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('WhatsApp opened. Press Send to deliver it.')));
    } else {
      await _showWhatsAppError(context, ref, invitation);
    }
  }

  static Future<void> _showWhatsAppError(
    BuildContext context,
    WidgetRef ref,
    Invitation invitation,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('WhatsApp could not be opened'),
        content: Text(
            'The invitation is preserved for ${invitation.phone}. You can copy it below, retry, or correct the number.'),
        actions: [
          TextButton(
              onPressed: () => _copyInvitation(context, invitation),
              child: const Text('COPY INVITATION')),
          TextButton(
              onPressed: () => Navigator.of(dialog).pop('retry'),
              child: const Text('RETRY WHATSAPP')),
          TextButton(
              onPressed: () => Navigator.of(dialog).pop('close'),
              child: const Text('CLOSE')),
          FilledButton(
              onPressed: () => Navigator.of(dialog).pop('edit'),
              child: const Text('EDIT NUMBER')),
        ],
      ),
    );
    if (action == 'edit' && context.mounted) {
      await _showReplacementSheet(context, ref, invitation);
    } else if (action == 'retry' && context.mounted) {
      await _openExistingInvitation(context, ref, invitation);
    }
  }

  static Future<void> _copyInvitation(
      BuildContext context, Invitation invitation) async {
    final copied = await _copyText(_invitationMessage(invitation));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            copied ? 'Invitation Copied' : 'Could not copy the invitation.')));
  }

  static Future<void> _copyPhone(
      BuildContext context, Invitation invitation) async {
    final copied = await _copyText(invitation.phone);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(copied
            ? 'Phone number copied'
            : 'Could not copy the phone number.')));
  }

  static Future<bool> _copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _showReplacementSheet(
    BuildContext context,
    WidgetRef ref,
    Invitation oldInvitation,
  ) async {
    final name = TextEditingController(text: oldInvitation.name);
    final phone = TextEditingController(text: oldInvitation.phone);
    final note = TextEditingController(text: oldInvitation.note);
    final formKey = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Correct invitation number',
                  style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Correct WhatsApp number'),
                validator: (v) => !isValidPhone(v ?? '')
                    ? 'Enter a valid international number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: note,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 16),
              GoldButton(
                label: 'CREATE REPLACEMENT',
                icon: Icons.swap_horiz_rounded,
                expand: true,
                onPressed: () async {
                  _normalisePhoneController(phone);
                  if (!formKey.currentState!.validate()) return;
                  try {
                    final token = await ref
                        .read(communityRepositoryProvider)
                        .replaceInvitation(
                          token: oldInvitation.token,
                          name: name.text,
                          phone: phone.text,
                          note: note.text,
                        );
                    final replacement = Invitation(
                      token: token,
                      name: name.text.trim(),
                      phone: normalizePhone(phone.text),
                      status: 'pending',
                      note: note.text.trim(),
                      expiresAt: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (!sheet.mounted) return;
                    Navigator.of(sheet).pop();
                    if (context.mounted) {
                      await _showInvitationActions(context, ref, replacement);
                    }
                  } catch (e) {
                    if (sheet.mounted) {
                      ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(
                          content: Text('Could not replace invitation: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationTile extends ConsumerWidget {
  const _InvitationTile({required this.invitation});

  final Invitation invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = invitation.isPending
        ? 'Pending · expires ${formatDate(invitation.expiresAt)}'
        : invitation.status;
    return GlassCard(
      blur: false,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(name: invitation.name),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(invitation.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(invitation.phone,
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: invitation.isPending
                                ? AppColors.roseGold
                                : null))
                  ])),
            ],
          ),
          if (invitation.isPending) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.whatsapp),
                  onPressed: () => _InvitationsTab._openExistingInvitation(
                      context, ref, invitation),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('OPEN WHATSAPP'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _InvitationsTab._openExistingInvitation(
                      context, ref, invitation),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('RETRY WHATSAPP'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _InvitationsTab._copyInvitation(context, invitation),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('COPY INVITATION'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _InvitationsTab._copyPhone(context, invitation),
                  icon: const Icon(Icons.phone_rounded),
                  label: const Text('COPY PHONE NUMBER'),
                ),
                IconButton(
                  tooltip: 'Cancel invite',
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => ref
                      .read(communityRepositoryProvider)
                      .cancelInvitation(invitation.token),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RosterTab extends ConsumerWidget {
  const _RosterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(communityRosterProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-community',
        backgroundColor: AppColors.roseGold,
        foregroundColor: Colors.white,
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add person'),
      ),
      body: roster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
            icon: Icons.error_outline, title: 'Could not load', message: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.groups_rounded,
                title: 'No community members yet',
                message:
                    'Use Add member in the Invitations tab for account access. '
                    'This roster remains available for text-only event participants.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _PersonTile(person: list[i]),
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add community member',
                  style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Login / WhatsApp number',
                  helperText:
                      '10 digits → +${AppConstants.defaultCountryCode} is added automatically',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (v) => normalizePhone(v ?? '').length < 11
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 20),
              GoldButton(
                label: 'ADD',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final messenger = ScaffoldMessenger.of(context);
                  ref
                      .read(communityRepositoryProvider)
                      .add(name: name.text, phone: normalizePhone(phone.text))
                      .catchError((Object e) {
                    messenger.showSnackBar(
                        SnackBar(content: Text('Could not add: $e')));
                  });
                  Navigator.of(sheet).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.person});

  final CommunityPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      blur: false,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          MemberAvatar(name: person.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(person.phone,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('Remove ${person.name}?'),
                  content: const Text(
                      'They will no longer be able to register. Existing accounts are not deleted.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Remove')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(communityRepositoryProvider).remove(person.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AccessTab extends ConsumerWidget {
  const _AccessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(registeredUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
          icon: Icons.error_outline, title: 'Could not load', message: '$e'),
      data: (list) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          GlassCard(
            blur: false,
            radius: 18,
            color: AppColors.blush,
            child: Text(
              'Switch on “Kuri” to let a registered user see ledgers and the Pamparam draw. '
              'To include them in monthly collections and draws, also add them to the Kuri roster '
              'from the Kuri Ledger.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.berry),
            ),
          ),
          const SizedBox(height: 12),
          for (final u in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                blur: false,
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    MemberAvatar(
                        name: u.name, highlight: u.isKuriMember || u.isAdmin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(u.isAdmin ? 'Administrator' : (u.phone ?? ''),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (u.isAdmin)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.verified_user_rounded,
                            color: AppColors.roseGold),
                      )
                    else ...[
                      Text(u.status == 'active' ? 'Active' : 'Disabled',
                          style: Theme.of(context).textTheme.labelMedium),
                      Switch.adaptive(
                        value: u.status == 'active',
                        activeColor: AppColors.blossom,
                        onChanged: (v) => ref
                            .read(communityRepositoryProvider)
                            .setMemberStatus(u.uid, v),
                      ),
                      Text('Kuri',
                          style: Theme.of(context).textTheme.labelMedium),
                      Switch.adaptive(
                        value: u.isKuriMember,
                        activeColor: AppColors.blossom,
                        onChanged: (v) => ref
                            .read(communityRepositoryProvider)
                            .setKuriMember(u.uid, v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
