import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../events/presentation/providers/events_providers.dart';
import '../../kuri/presentation/providers/kuri_providers.dart';
import '../../lottery_wheel/presentation/providers/wheel_providers.dart';
import '../../quiz/presentation/providers/quiz_providers.dart';

enum RefreshOutcome { refreshed, offline }

/// Deep berry from the CheraSakhi palette (#4A0E2E).
const _deepBerry = Color(0xFF4A0E2E);

/// Pulls the latest data from the server and re-subscribes every live stream.
///
/// Firestore is already real-time, so this is mainly for reassurance and for
/// recovering after the phone was offline: it re-enables the network, does one
/// server round-trip, then invalidates the data providers.
Future<RefreshOutcome> refreshAppData(WidgetRef ref) async {
  final db = ref.read(firestoreProvider);
  final started = DateTime.now();
  var outcome = RefreshOutcome.refreshed;

  try {
    await db.enableNetwork();
    await db
        .collection('members')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    outcome = RefreshOutcome.offline; // cached data stays on screen
  }

  // Families are invalidated as a whole (every month / cycle / event).
  ref.invalidate(membersProvider);
  ref.invalidate(activeCycleProvider);
  ref.invalidate(paymentsProvider);
  ref.invalidate(claimsProvider);
  ref.invalidate(drawsProvider);
  ref.invalidate(eventsProvider);
  ref.invalidate(contributionsProvider);
  ref.invalidate(expensesProvider);
  ref.invalidate(transfersProvider);
  ref.invalidate(quizContestsProvider);
  // NOTE: appUserProvider is deliberately NOT invalidated — AuthGate would
  // flash the splash screen and reset the selected tab.

  // Keep the spinner visible long enough to feel responsive, not glitchy.
  final elapsed = DateTime.now().difference(started);
  const minVisible = Duration(milliseconds: 700);
  if (elapsed < minVisible) await Future<void>.delayed(minVisible - elapsed);
  return outcome;
}

/// Subtle bottom confirmation.
void showRefreshSnackBar(BuildContext context, RefreshOutcome outcome) {
  final ok = outcome == RefreshOutcome.refreshed;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: ok ? _deepBerry : const Color(0xFF5B4A52),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                color: AppColors.roseGoldPale, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ok
                    ? 'ഡാറ്റ അപ്‌ഡേറ്റ് ചെയ്തു (Data refreshed)'
                    : 'ഓഫ്‌ലൈൻ — സേവ് ചെയ്ത ഡാറ്റ കാണിക്കുന്നു (Offline – showing saved data)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Rose-gold circular refresh button for AppBars. Spins while refreshing.
class RefreshActionButton extends ConsumerStatefulWidget {
  const RefreshActionButton({super.key, this.size = 40});

  final double size;

  @override
  ConsumerState<RefreshActionButton> createState() => _RefreshActionButtonState();
}

class _RefreshActionButtonState extends ConsumerState<RefreshActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  bool _busy = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    _spin.repeat();

    final outcome = await refreshAppData(ref);

    if (!mounted) return;
    _spin.stop();
    await _spin.animateTo(1, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    if (!mounted) return;
    _spin.reset();
    setState(() => _busy = false);
    showRefreshSnackBar(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _refresh,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.roseGoldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.roseGold.withOpacity(_busy ? 0.55 : 0.30),
                  blurRadius: _busy ? 14 : 8,
                ),
              ],
            ),
            child: RotationTransition(
              turns: _spin,
              child: Icon(Icons.refresh_rounded, color: Colors.white, size: widget.size * 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pull-to-refresh wrapper in brand colours.
///
/// The child must be scrollable; give it
/// `physics: const AlwaysScrollableScrollPhysics()` so short lists can still be pulled.
class AppRefreshIndicator extends ConsumerWidget {
  const AppRefreshIndicator({super.key, required this.child, this.edgeOffset = 0});

  final Widget child;
  final double edgeOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _deepBerry,
      backgroundColor: AppColors.roseGoldPale,
      edgeOffset: edgeOffset,
      displacement: 56,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        final outcome = await refreshAppData(ref);
        if (context.mounted) showRefreshSnackBar(context, outcome);
      },
      child: child,
    );
  }
}
