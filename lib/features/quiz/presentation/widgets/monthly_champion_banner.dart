import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
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
  QuizPrizeSelection? _prize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      reverseDuration: const Duration(milliseconds: 450),
    );
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
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _dismissTimer = Timer(const Duration(seconds: 7), _dismiss);
  }

  void _dismiss() {
    if (!_visible) return;
    _dismissTimer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
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

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.2),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
            backgroundImage: photo == null ? null : NetworkImage(photo),
            onBackgroundImageError: photo == null ? null : (_, __) {},
            child: photo == null
                ? Text(championInitials(prize.recipientName),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))
                : null,
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
