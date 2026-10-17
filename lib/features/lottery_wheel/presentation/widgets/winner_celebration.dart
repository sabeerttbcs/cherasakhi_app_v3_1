import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';

Future<void> showWinnerCelebration(
  BuildContext context, {
  required String winnerName,
  required int seatNo,
  required double amount,
  required String monthLabel,
  required String cycleName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Winner',
    barrierColor: Colors.black.withOpacity(0.82),
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (_, __, ___) => WinnerCelebration(
      winnerName: winnerName,
      seatNo: seatNo,
      amount: amount,
      monthLabel: monthLabel,
      cycleName: cycleName,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

class WinnerCelebration extends StatefulWidget {
  const WinnerCelebration({
    super.key,
    required this.winnerName,
    required this.seatNo,
    required this.amount,
    required this.monthLabel,
    required this.cycleName,
  });

  final String winnerName;
  final int seatNo;
  final double amount;
  final String monthLabel;
  final String cycleName;

  @override
  State<WinnerCelebration> createState() => _WinnerCelebrationState();
}

class _WinnerCelebrationState extends State<WinnerCelebration> {
  final _cardKey = GlobalKey();
  final _burst = ConfettiController(duration: const Duration(seconds: 2));
  final _rain = ConfettiController(duration: const Duration(seconds: 6));
  bool _sharing = false;

  static const _colors = [
    AppColors.roseGoldLight,
    AppColors.roseGoldPale,
    AppColors.blossom,
    Colors.white,
    AppColors.lavender,
    AppColors.blossom,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _burst.play();
      _rain.play();
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    _rain.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pamparam_winner_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '🎉 Congratulations ${widget.winnerName}! Winner of the ${widget.monthLabel} Kuri '
            '(${formatMoney(widget.amount)}) in our Pamparam lucky draw 🏆 — ${AppConstants.appName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _rain,
              blastDirection: pi / 2,
              emissionFrequency: 0.08,
              numberOfParticles: 10,
              maxBlastForce: 10,
              minBlastForce: 4,
              gravity: 0.22,
              colors: _colors,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: _cardKey,
                      child: WinnerShareCard(
                        winnerName: widget.winnerName,
                        seatNo: widget.seatNo,
                        amount: widget.amount,
                        monthLabel: widget.monthLabel,
                        cycleName: widget.cycleName,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 320,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GoldButton(
                              label: 'SHARE',
                              icon: Icons.ios_share_rounded,
                              loading: _sharing,
                              expand: true,
                              onPressed: _share,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _burst,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              maxBlastForce: 45,
              minBlastForce: 15,
              gravity: 0.18,
              colors: _colors,
            ),
          ),
        ],
      ),
    );
  }
}

/// The exportable announcement card (captured to PNG for WhatsApp).
class WinnerShareCard extends StatelessWidget {
  const WinnerShareCard({
    super.key,
    required this.winnerName,
    required this.seatNo,
    required this.amount,
    required this.monthLabel,
    required this.cycleName,
  });

  final String winnerName;
  final int seatNo;
  final double amount;
  final String monthLabel;
  final String cycleName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: AppColors.roseGoldGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppColors.roseGoldLight.withOpacity(0.45), blurRadius: 40)],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          gradient: AppColors.berryGradient,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✦  PAMPARAM LUCKY DRAW  ✦',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.roseGoldPale,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.roseGoldLight.withOpacity(0.45),
                  AppColors.roseGoldLight.withOpacity(0.0),
                ]),
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 76, color: AppColors.roseGoldPale),
            ),
            const SizedBox(height: 12),
            Text('Congratulations, Sakhi!',
                style: GoogleFonts.playfairDisplay(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              winnerName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),
            ),
            Text('Seat #$seatNo', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.roseGoldGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                formatMoney(amount),
                style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text('$monthLabel  ·  $cycleName',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.12), height: 1),
            const SizedBox(height: 12),
            Text(
              '${AppConstants.appName.toUpperCase()} · ${AppConstants.fullName}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.roseGoldPale, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
