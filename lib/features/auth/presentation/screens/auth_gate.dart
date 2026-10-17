import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/firebase_providers.dart';
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
        return ref.watch(appUserProvider).when(
              loading: () => const _Splash(),
              error: (e, _) => _AccountProblem(message: '$e'),
              data: (profile) {
                if (profile == null) return const _AccountProblem(message: 'Your account is not configured by an admin.');
                if (profile.isDisabled) return const _AccountProblem(message: 'This account is disabled. Contact the admin.');
                return const HomeShell();
              },
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

class _AccountProblem extends ConsumerWidget {
  const _AccountProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_rounded, size: 72, color: AppColors.roseGold),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
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
      ),
    );
  }
}
