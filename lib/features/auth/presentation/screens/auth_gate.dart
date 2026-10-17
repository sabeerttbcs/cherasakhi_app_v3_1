import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../home/presentation/home_shell.dart';
import '../providers/auth_providers.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => _Splash(message: '$e'),
      data: (user) {
        if (user == null) return const LoginScreen();
        final profile = ref.watch(appUserProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (_, __) => _ProfileBootstrap(key: ValueKey('boot-${user.uid}'), user: user),
          data: (p) => p == null
              ? _ProfileBootstrap(key: ValueKey('boot-${user.uid}'), user: user)
              : const HomeShell(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.berryGradient),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/logo.png', width: 200, height: 200),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.roseGoldLight),
            if (message != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

/// Links a freshly signed-in phone user to their `members` record.
class _ProfileBootstrap extends ConsumerStatefulWidget {
  const _ProfileBootstrap({super.key, required this.user});

  final User user;

  @override
  ConsumerState<_ProfileBootstrap> createState() => _ProfileBootstrapState();
}

class _ProfileBootstrapState extends ConsumerState<_ProfileBootstrap> {
  bool _notRegistered = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final ok = await ref.read(authRepositoryProvider).bootstrapMemberProfile(widget.user);
      if (!ok && mounted) setState(() => _notRegistered = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notRegistered = true;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_notRegistered) return const _Splash();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search_rounded, size: 72, color: AppColors.roseGold),
              const SizedBox(height: 16),
              Text('Not registered yet', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Your number ${widget.user.phoneNumber ?? widget.user.email ?? ''} is not on the Kuri or community member list. '
                'Please ask the admin to add you, then sign in again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text('Your account UID (for admin setup):', style: theme.textTheme.bodySmall),
              SelectableText(widget.user.uid, style: theme.textTheme.titleSmall),
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: widget.user.uid)),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy UID'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 24),
              GoldButton(
                label: 'SIGN OUT',
                icon: Icons.logout_rounded,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
