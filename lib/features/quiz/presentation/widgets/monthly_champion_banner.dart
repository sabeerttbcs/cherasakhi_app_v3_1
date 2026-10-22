import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../data/quiz_report_repository.dart';
import '../../domain/entities/quiz_report_models.dart';
import '../providers/quiz_providers.dart';

class MonthlyChampionBanner extends ConsumerStatefulWidget {
  const MonthlyChampionBanner({super.key});

  @override
  ConsumerState<MonthlyChampionBanner> createState() =>
      _MonthlyChampionBannerState();
}

class _MonthlyChampionBannerState extends ConsumerState<MonthlyChampionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;
  bool _visible = false;
  bool _reducedMotion = false;
  bool _soundMuted = false;
  QuizPrizeSelection? _prize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      reverseDuration: const Duration(milliseconds: 450),
    );
    _soundMuted = NotificationService.instance.muted.value;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(QuizPrizeSelection prize) {
    if (_visible || ref.read(monthlyChampionShownProvider)) return;
    ref.read(monthlyChampionShownProvider.notifier).state = true;
    _prize = prize;
    _visible = true;
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _dismissTimer = Timer(const Duration(seconds: 7), _dismiss);
  }

  void _dismiss() {
    if (!_visible) return;
    _dismissTimer?.cancel();
    if (_reducedMotion) {
      if (mounted) setState(() => _visible = false);
      return;
    }
    _controller.reverse().whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _toggleMute() {
    _soundMuted = !_soundMuted;
    NotificationService.instance.muted.value = _soundMuted;
    setState(() {});
  }

  void _playCelebrationSound() {
    if (_soundMuted) return;
    // This is deliberately user-triggered. Browser/PWA autoplay policies may
    // reject the call; NotificationService catches and ignores that safely.
    NotificationService.instance
        .playSound('sounds/chime.wav', volume: 0.65)
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final asyncPrize = ref.watch(latestMonthlyChampionProvider);
    final prize = asyncPrize.valueOrNull;
    if (prize != null && !ref.watch(monthlyChampionShownProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show(prize);
      });
    }
    final current = _prize;
    if (!_visible || current == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  // Horizontal entrance: the congratulations flag scrolls in
                  // from the left instead of dropping vertically.
                  begin: const Offset(-1.15, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: _controller,
                  child: RepaintBoundary(
                    child: _BannerCard(prize: current),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                      _soundMuted ? 'Sound muted' : 'Play celebration sound',
                  onPressed: _soundMuted ? null : _playCelebrationSound,
                  icon: const Icon(Icons.volume_up_rounded),
                  color: Colors.white,
                  iconSize: 18,
                ),
                IconButton(
                  tooltip: _soundMuted ? 'Enable sound' : 'Mute sound',
                  onPressed: _toggleMute,
                  icon: Icon(_soundMuted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none_outlined),
                  color: Colors.white70,
                  iconSize: 17,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.prize});

  final QuizPrizeSelection prize;

  @override
  Widget build(BuildContext context) {
    final photo = isConsentPhotoUrl(prize.photoUrl) ? prize.photoUrl : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 11, 104, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D1744), Color(0xFFB7791F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            child: photo == null
                ? Text(championInitials(prize.recipientName),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))
                : ClipOval(
                    child: Image.network(
                      photo,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        championInitials(prize.recipientName),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏆 Congratulations!',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('🌸 Our Monthly Quiz Champion · ${prize.recipientName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                      'Well Done! Who will be our next Champion? · ${prize.monthKey}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
                  const Text('അഭിനന്ദനങ്ങൾ! അടുത്ത ചാമ്പ്യൻ നിങ്ങളാകട്ടെ 🌸',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.roseGoldPale, size: 22),
        ],
      ),
    );
  }
}
