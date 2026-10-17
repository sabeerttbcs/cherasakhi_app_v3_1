import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/gold_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/profile_menu_button.dart';

enum KuriAccess { checking, granted, denied }

/// Single source of truth for "may this user see Kuri data?".
/// Firestore rules enforce the same thing server-side (`isKuri()`).
final kuriAccessProvider = Provider<KuriAccess>((ref) {
  final user = ref.watch(appUserProvider);
  return user.when(
    data: (u) => (u?.canAccessKuri ?? false) ? KuriAccess.granted : KuriAccess.denied,
    loading: () => KuriAccess.checking,
    error: (_, __) => KuriAccess.denied,
  );
});

/// Convenience bool for code that only needs yes/no (e.g. alert listeners).
final canAccessKuriProvider = Provider<bool>((ref) => ref.watch(kuriAccessProvider) == KuriAccess.granted);

/// Route guard for Kuri screens.
///
/// The child is only *built* when access is granted, so its Firestore
/// listeners never start for community-only members.
class KuriGuard extends ConsumerWidget {
  const KuriGuard({super.key, required this.child, this.onOpenQuiz});

  final Widget child;

  /// Optional shortcut shown on the lock screen.
  final VoidCallback? onOpenQuiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(kuriAccessProvider)) {
      KuriAccess.granted => child,
      KuriAccess.checking => const Scaffold(body: Center(child: CircularProgressIndicator())),
      KuriAccess.denied => KuriLockedView(onOpenQuiz: onOpenQuiz),
    };
  }
}

/// Clean lock banner for non-enrolled members.
class KuriLockedView extends StatelessWidget {
  const KuriLockedView({super.key, this.onOpenQuiz});

  final VoidCallback? onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(padding: EdgeInsets.all(12), child: ProfileMenuButton()),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.berryGradient,
                            border: Border.all(color: AppColors.roseGoldLight, width: 2),
                            boxShadow: [
                              BoxShadow(color: AppColors.berry.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: const Icon(Icons.lock_rounded, color: AppColors.roseGoldPale, size: 46),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'നിങ്ങൾ ഈ കുറിയിൽ അംഗമല്ല',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansMalayalam(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kuri section is available to enrolled members only',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Monthly ledgers, payment lists and the Pamparam draw are private to the Kuri cohort. '
                          'Please contact the admin if you would like to join the next cycle.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                        ),
                        if (onOpenQuiz != null) ...[
                          const SizedBox(height: 28),
                          GoldButton(label: 'OPEN LIVE QUIZ', icon: Icons.quiz_rounded, onPressed: onOpenQuiz),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
