import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/guards/kuri_guard.dart';
import '../../events/presentation/screens/events_list_screen.dart';
import '../../kuri/presentation/screens/member_checklist_screen.dart';
import '../../lottery_wheel/presentation/screens/spin_wheel_screen.dart';
import '../../quiz/presentation/screens/quiz_hub_screen.dart';
import '../../quiz/presentation/widgets/live_quiz_banner.dart';
import 'app_alerts_listener.dart';

/// Tab order. Kuri tabs are wrapped in [KuriGuard]; Quiz is open to everyone.
enum HomeTab { kuriLedger, pamparam, tourWallet, liveQuiz }

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int? _index;

  void _go(HomeTab tab) {
    HapticFeedback.selectionClick();
    setState(() => _index = tab.index);
  }

  @override
  Widget build(BuildContext context) {
    // Community-only members land on the Live Quiz tab; Kuri members on the ledger.
    final access = ref.watch(kuriAccessProvider);
    final index = _index ??
        (access == KuriAccess.denied ? HomeTab.liveQuiz.index : HomeTab.kuriLedger.index);
    void openQuiz() => _go(HomeTab.liveQuiz);

    return Scaffold(
      body: AppAlertsListener(
        child: IndexedStack(
          index: index,
          children: [
            KuriGuard(onOpenQuiz: openQuiz, child: const MemberChecklistScreen()),
            KuriGuard(onOpenQuiz: openQuiz, child: const SpinWheelScreen()),
            const EventsListScreen(),
            const QuizHubScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveQuizBanner(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => _go(HomeTab.values[i]),
            destinations: [
              NavigationDestination(
                icon: Icon(access == KuriAccess.denied ? Icons.lock_outline_rounded : Icons.fact_check_outlined),
                selectedIcon: const Icon(Icons.fact_check_rounded),
                label: 'Kuri Ledger',
              ),
              NavigationDestination(
                icon: Icon(access == KuriAccess.denied ? Icons.lock_outline_rounded : Icons.attractions_outlined),
                selectedIcon: const Icon(Icons.attractions_rounded),
                label: 'Pamparam',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Tour Wallet',
              ),
              const NavigationDestination(
                icon: Icon(Icons.quiz_outlined),
                selectedIcon: Icon(Icons.quiz_rounded),
                label: 'Live Quiz',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
