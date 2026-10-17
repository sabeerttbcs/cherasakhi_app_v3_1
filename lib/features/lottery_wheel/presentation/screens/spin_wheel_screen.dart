import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month_key.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/profile_menu_button.dart';
import '../../../home/presentation/app_refresh.dart';
import '../../../kuri/domain/entities/member.dart';
import '../../../kuri/presentation/widgets/month_switcher.dart';
import '../../domain/entities/draw_record.dart';
import '../../domain/repositories/draw_repository.dart';
import '../../domain/usecases/eligibility.dart';
import '../providers/wheel_providers.dart';
import '../widgets/wheel_painter.dart';
import '../widgets/wheel_sfx.dart';
import '../widgets/winner_celebration.dart';

/// Pamparam live lucky-draw wheel.
///
/// Fairness & integrity:
///  * Slices = only ELIGIBLE members (paid this month AND never won this cycle).
///  * Winner is chosen with `Random.secure()` and COMMITTED to Firestore
///    (transaction + create-only security rules) BEFORE the animation starts,
///    so the result can't be re-rolled by closing the app mid-spin.
///  * The wheel then decelerates with a friction curve onto the winner's slice.
class SpinWheelScreen extends ConsumerStatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);
  double _angle = 0;

  /// Slices frozen at spin start — the live list changes as soon as the
  /// winner is committed, but the wheel must keep showing the same slices.
  List<Member> _frozen = const [];
  bool _spinning = false;
  int _lastIndex = -1;
  DateTime _lastTickAt = DateTime.fromMillisecondsSinceEpoch(0);
  final WheelSfx _sfx = WheelSfx();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 7800))
      ..addListener(_onFrame);
  }

  @override
  void dispose() {
    _controller.dispose();
    _sfx.dispose();
    super.dispose();
  }

  static double _norm(double a) {
    final t = a % (2 * pi);
    return t < 0 ? t + 2 * pi : t;
  }

  /// Fires a tick + haptic each time a new slice passes the pointer.
  void _onFrame() {
    final n = _frozen.length;
    if (n == 0) return;
    final sweep = 2 * pi / n;
    final idx = (_norm(-_rotation.value) / sweep).floor() % n;
    if (idx == _lastIndex) return;
    _lastIndex = idx;
    final now = DateTime.now();
    if (now.difference(_lastTickAt).inMilliseconds >= 40) {
      _lastTickAt = now;
      _sfx.tick();
      HapticFeedback.selectionClick();
    }
  }

  /// Writes the result first (transaction). Returns null and resets on failure.
  Future<DrawRecord?> _commit(WheelData data, Member winner, int eligibleCount, String uid) async {
    try {
      return await ref.read(drawRepositoryProvider).commitDraw(
            cycleId: data.cycle.id,
            monthKey: data.monthKey,
            winner: winner,
            amount: data.potAmount,
            eligibleCount: eligibleCount,
            drawnBy: uid,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _spinning = false;
          _frozen = const [];
        });
        final msg = e is DrawException ? e.message : 'Draw failed (are you online?): $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return null;
    }
  }

  Future<void> _spin(WheelData data) async {
    if (_spinning) return;
    final slices = List<Member>.of(data.eligibility.eligible);
    final uid = ref.read(currentUidProvider);
    if (slices.isEmpty || uid == null) return;

    final rng = Random.secure();
    final winnerIndex = rng.nextInt(slices.length);
    final winner = slices[winnerIndex];

    setState(() {
      _spinning = true;
      _frozen = slices;
      _lastIndex = -1;
    });
    HapticFeedback.mediumImpact();

    final record = await _commit(data, winner, slices.length, uid);
    if (record == null) return;

    // Land the pointer inside the winner's slice, with natural jitter.
    final sweep = 2 * pi / slices.length;
    final jitter = (rng.nextDouble() - 0.5) * 0.7 * sweep;
    final target = _norm(-(winnerIndex + 0.5) * sweep + jitter);
    var delta = target - _norm(_angle);
    if (delta < 0) delta += 2 * pi;
    final end = _angle + (7 + rng.nextInt(3)) * 2 * pi + delta;

    _rotation = Tween<double>(begin: _angle, end: end)
        .animate(CurvedAnimation(parent: _controller, curve: const _FrictionCurve()));
    _controller.reset();
    await _controller.forward();
    _angle = end;
    if (!mounted) return;

    _sfx.win();
    HapticFeedback.heavyImpact();
    setState(() => _spinning = false);

    await showWinnerCelebration(
      context,
      winnerName: winner.name,
      seatNo: winner.seatNo,
      amount: record.amount,
      monthLabel: MonthKey.label(record.monthKey),
      cycleName: data.cycle.name,
    );
    if (mounted) setState(() => _frozen = const []);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wheelDataProvider);
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', message: '$e'),
            data: (data) => data == null
                ? const EmptyState(
                    icon: Icons.attractions_rounded,
                    title: 'No active Kuri cycle',
                    message: 'Start a cycle from the Kuri Ledger tab to unlock the Pamparam draw.',
                  )
                : _content(context, data, isAdmin),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WheelData data, bool isAdmin) {
    final theme = Theme.of(context);
    final slices = _frozen.isNotEmpty ? _frozen : data.eligibility.eligible;
    final showWheel = _frozen.isNotEmpty || (data.monthDraw == null && slices.isNotEmpty);

    return AppRefreshIndicator(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pamparam Draw', style: theme.textTheme.headlineSmall),
                    Text('Live lucky draw · fair & transparent', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const RefreshActionButton(),
            const SizedBox(width: 8),
            const ProfileMenuButton(),
            ],
          ),
          const SizedBox(height: 12),
          IgnorePointer(ignoring: _spinning || _frozen.isNotEmpty, child: MonthSwitcher(cycle: data.cycle)),
          const SizedBox(height: 12),
          _PotCard(data: data),
          const SizedBox(height: 22),
          if (showWheel) ...[
            _wheel(slices),
            const SizedBox(height: 26),
            if (isAdmin)
              GoldButton(
                label: _spinning ? 'SPINNING…' : 'SPIN THE WHEEL',
                icon: Icons.casino_rounded,
                loading: _spinning,
                expand: true,
                onPressed: _spinning || _frozen.isNotEmpty ? null : () => _spin(data),
              )
            else
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: AppColors.roseGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Only the admin can spin. The winner appears here live.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ] else if (data.monthDraw != null)
            _DrawCompletedCard(record: data.monthDraw!, cycleName: data.cycle.name)
          else
            const EmptyState(
              icon: Icons.person_off_rounded,
              title: 'No eligible members',
              message: 'Mark installments as PAID in the Kuri Ledger. Previous winners are excluded automatically.',
            ),
          const SizedBox(height: 18),
          _EligibilityPanel(eligibility: data.eligibility),
          _WinnersTimeline(draws: data.draws),
        ],
      ),
    );
  }

  Widget _wheel(List<Member> slices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 380.0);
        const top = 18.0;
        return Center(
          child: SizedBox(
            width: size,
            height: size + top,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: top,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.roseGoldLight.withOpacity(_spinning ? 0.6 : 0.25),
                          blurRadius: _spinning ? 50 : 28,
                          spreadRadius: _spinning ? 6 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: top,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, child) => Transform.rotate(angle: _rotation.value, child: child),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: WheelPainter(labels: [for (final m in slices) m.name]),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: top + size / 2 - 36,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.roseGoldGradient,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 26),
                        Text('${slices.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const Positioned(top: 0, child: WheelPointer()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fast start, long suspenseful friction-like slowdown.
class _FrictionCurve extends Curve {
  const _FrictionCurve();

  @override
  double transformInternal(double t) => 1 - pow(1 - t, 3.6).toDouble();
}

class _PotCard extends StatelessWidget {
  const _PotCard({required this.data});

  final WheelData data;

  @override
  Widget build(BuildContext context) {
    final e = data.eligibility;
    return GlassCard(
      blur: false,
      gradient: AppColors.berryGradient,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.roseGoldGradient),
                child: const Icon(Icons.savings_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${MonthKey.label(data.monthKey)} Kuri pot',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                    Text(formatMoney(data.potAmount),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Eligible ${e.eligible.length}', AppColors.blossom),
              _chip('Unpaid ${e.unpaid.length}', AppColors.roseGoldLight),
              _chip('Already won ${e.alreadyWon.length}', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _DrawCompletedCard extends StatelessWidget {
  const _DrawCompletedCard({required this.record, required this.cycleName});

  final DrawRecord record;
  final String cycleName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderColor: AppColors.roseGoldLight.withOpacity(0.6),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, size: 64, color: AppColors.roseGoldLight),
          const SizedBox(height: 8),
          Text('Draw completed for ${MonthKey.label(record.monthKey)}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(record.winnerName, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          Text(formatMoney(record.amount), style: theme.textTheme.titleLarge?.copyWith(color: AppColors.roseGold)),
          const SizedBox(height: 4),
          Text('${record.eligibleCount} eligible · drawn ${formatDateTime(record.drawnAt)}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 18),
          GoldButton(
            label: 'CELEBRATE & SHARE',
            icon: Icons.celebration_rounded,
            onPressed: () => showWinnerCelebration(
              context,
              winnerName: record.winnerName,
              seatNo: record.winnerSeatNo,
              amount: record.amount,
              monthLabel: MonthKey.label(record.monthKey),
              cycleName: cycleName,
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibilityPanel extends StatelessWidget {
  const _EligibilityPanel({required this.eligibility});

  final EligibilityResult eligibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget names(String title, List<Member> list, Color color) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title (${list.length})', style: theme.textTheme.labelLarge?.copyWith(color: color)),
              const SizedBox(height: 6),
              Text(list.isEmpty ? '—' : list.map((m) => m.name).join(', '), style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.verified_user_rounded, color: AppColors.blossom),
          title: const Text('Eligibility rules'),
          subtitle: const Text('Paid this month · not won before in this cycle'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            names('On the wheel', eligibility.eligible, AppColors.blossom),
            names('Excluded – unpaid', eligibility.unpaid, AppColors.roseGold),
            names('Excluded – already won', eligibility.alreadyWon, theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _WinnersTimeline extends StatelessWidget {
  const _WinnersTimeline({required this.draws});

  final List<DrawRecord> draws;

  @override
  Widget build(BuildContext context) {
    if (draws.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Winners this cycle', subtitle: '${draws.length} draw(s) completed'),
        for (final d in draws.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              blur: false,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.roseGoldLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.roseGold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.winnerName, style: theme.textTheme.titleSmall),
                        Text(MonthKey.label(d.monthKey), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(formatMoneyCompact(d.amount), style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
