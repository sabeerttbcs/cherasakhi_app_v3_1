import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/usecases/quiz_evaluation.dart';
import 'quiz_format.dart';

/// Circular progress + digital countdown whose colour moves from teal to
/// amber to crimson, with a soft pulse in the final crunch.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.fraction,
    required this.tone,
    this.caption,
    this.size = 168,
  });

  final Duration remaining;

  /// 1.0 = full time left, 0.0 = finished.
  final double fraction;
  final TimerTone tone;
  final String? caption;
  final double size;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) _syncPulse();
  }

  void _syncPulse() {
    if (widget.tone == TimerTone.critical) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: TimerColors.main(widget.tone)),
      duration: const Duration(milliseconds: 700),
      builder: (context, color, _) {
        final c = color ?? TimerColors.calm;
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final p = Curves.easeInOut.transform(_pulse.value);
            return Transform.scale(
              scale: 1 + 0.035 * p,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: c.withOpacity(0.25 + 0.35 * p), blurRadius: 24 + 22 * p, spreadRadius: 2 * p),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.fraction),
                  duration: const Duration(milliseconds: 950),
                  curve: Curves.linear,
                  builder: (context, f, _) => CustomPaint(
                    painter: _RingPainter(
                      fraction: f,
                      color: c,
                      track: isDark ? Colors.white.withOpacity(0.10) : c.withOpacity(0.13),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: Text(
                                formatCountdown(widget.remaining),
                                style: GoogleFonts.poppins(
                                  fontSize: widget.size * 0.2,
                                  fontWeight: FontWeight.w700,
                                  color: c,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                          if (widget.caption != null)
                            Text(
                              widget.caption!,
                              style: TextStyle(
                                fontSize: widget.size * 0.07,
                                fontWeight: FontWeight.w600,
                                color: c.withOpacity(0.85),
                                letterSpacing: 0.6,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2 + 2);
    canvas.drawArc(
      inner,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      inner,
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [color.withOpacity(0.55), color],
          transform: const GradientRotation(-pi / 2),
        ).createShader(inner),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}
