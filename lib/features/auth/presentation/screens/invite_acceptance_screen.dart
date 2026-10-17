import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_providers.dart';

class InviteAcceptanceScreen extends ConsumerStatefulWidget {
  const InviteAcceptanceScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteAcceptanceScreen> createState() => _InviteAcceptanceScreenState();
}

class _InviteAcceptanceScreenState extends ConsumerState<InviteAcceptanceScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  InviteInfo? _invite;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final invite = await ref.read(authRepositoryProvider).getInvite(widget.token);
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final invite = _invite;
    if (invite == null || !invite.isPending) {
      setState(() => _error = 'This invitation is invalid or expired.');
      return;
    }
    if (_password.text.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).acceptInvite(token: widget.token, password: _password.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not create the account');
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Accept invitation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.mark_email_read_rounded, size: 72, color: AppColors.roseGold),
                const SizedBox(height: 16),
                Text(_invite == null ? 'Invitation unavailable' : 'Welcome to CheraSakhi',
                    textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                if (_invite != null) ...[
                  Text('This invitation is for ${_invite!.name}.', textAlign: TextAlign.center),
                  Text(normalizePhone(_invite!.phone), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  if (_invite!.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_invite!.note, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Create password', prefixIcon: Icon(Icons.lock_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  GoldButton(label: 'CREATE ACCOUNT', icon: Icons.person_add_alt_1_rounded, loading: _busy, expand: true, onPressed: _accept),
                ] else
                  Text(_error ?? 'Ask the admin for a new invitation.', textAlign: TextAlign.center),
              ],
            ),
    );
  }
}
