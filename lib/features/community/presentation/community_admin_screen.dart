import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gold_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../domain/community_models.dart';
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
        body: const TabBarView(children: [_InvitationsTab(), _RosterTab(), _AccessTab()]),
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
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not load invitations', message: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.mail_lock_rounded,
                title: 'No invitations yet',
                message: 'Create an invite to let a member create a password and sign in with their phone number.',
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
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add member & create invite', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)), validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name' : null),
              const SizedBox(height: 12),
              TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / WhatsApp number', prefixIcon: Icon(Icons.phone_rounded)), validator: (v) => normalizePhone(v ?? '').length < 11 ? 'Enter a valid number' : null),
              const SizedBox(height: 12),
              TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_rounded)), maxLines: 2),
              const SizedBox(height: 20),
              GoldButton(
                label: 'CREATE WHATSAPP INVITE',
                icon: Icons.send_rounded,
                expand: true,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final token = await ref.read(communityRepositoryProvider).createInvitation(name: name.text, phone: phone.text, note: note.text);
                    final link = 'https://sakhi.sabeerlabs.com/?invite=$token';
                    await WhatsAppLauncher.send(phone: normalizePhone(phone.text), message: 'Hello ${name.text.trim()} 🌸\n\nYou are invited to CheraSakhi. Create your password here:\n$link\n\nThis one-time invitation expires in 7 days.');
                    if (context.mounted) Navigator.of(sheet).pop();
                    messenger.showSnackBar(const SnackBar(content: Text('Invitation created and WhatsApp opened.')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Could not create invitation: $e')));
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
    final status = invitation.isPending ? 'Pending · expires ${formatDate(invitation.expiresAt)}' : invitation.status;
    final link = 'https://sakhi.sabeerlabs.com/?invite=${invitation.token}';
    return GlassCard(
      blur: false,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          MemberAvatar(name: invitation.name),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(invitation.name, style: Theme.of(context).textTheme.titleSmall), Text(invitation.phone, style: Theme.of(context).textTheme.bodySmall), Text(status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: invitation.isPending ? AppColors.roseGold : null))])),
          if (invitation.isPending) ...[
            IconButton(tooltip: 'Send WhatsApp invite', icon: const Icon(Icons.chat_rounded), onPressed: () => WhatsAppLauncher.send(phone: invitation.phone, message: 'Join CheraSakhi and create your password:\n$link')),
            IconButton(tooltip: 'Cancel invite', icon: const Icon(Icons.cancel_outlined), onPressed: () => ref.read(communityRepositoryProvider).cancelInvitation(invitation.token)),
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
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not load', message: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.groups_rounded,
                title: 'No community members yet',
                message: 'Use Add member in the Invitations tab for account access. '
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
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add community member', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Login / WhatsApp number',
                  helperText: '10 digits → +${AppConstants.defaultCountryCode} is added automatically',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (v) => normalizePhone(v ?? '').length < 11 ? 'Enter a valid number' : null,
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
                    messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
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
                Text(person.name, style: Theme.of(context).textTheme.titleSmall),
                Text(person.phone, style: Theme.of(context).textTheme.bodySmall),
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
                  content: const Text('They will no longer be able to register. Existing accounts are not deleted.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
                  ],
                ),
              );
              if (ok == true) await ref.read(communityRepositoryProvider).remove(person.id);
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
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not load', message: '$e'),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.berry),
            ),
          ),
          const SizedBox(height: 12),
          for (final u in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                blur: false,
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    MemberAvatar(name: u.name, highlight: u.isKuriMember || u.isAdmin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name, style: Theme.of(context).textTheme.titleSmall),
                          Text(u.isAdmin ? 'Administrator' : (u.phone ?? ''),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (u.isAdmin)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.verified_user_rounded, color: AppColors.roseGold),
                      )
                    else ...[
                      Text(u.status == 'active' ? 'Active' : 'Disabled', style: Theme.of(context).textTheme.labelMedium),
                      Switch.adaptive(
                        value: u.status == 'active',
                        activeColor: AppColors.blossom,
                        onChanged: (v) => ref.read(communityRepositoryProvider).setMemberStatus(u.uid, v),
                      ),
                      Text('Kuri', style: Theme.of(context).textTheme.labelMedium),
                      Switch.adaptive(
                        value: u.isKuriMember,
                        activeColor: AppColors.blossom,
                        onChanged: (v) => ref.read(communityRepositoryProvider).setKuriMember(u.uid, v),
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
