import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints the static wheel (rotation is applied outside via Transform so the
/// expensive painting happens once and is cached in a RepaintBoundary).
/// Slice i spans [-π/2 + i·sweep, -π/2 + (i+1)·sweep] before rotation.
class WheelPainter extends CustomPainter {
  WheelPainter({required this.labels});

  final List<String> labels;

  static const _berry = [Color(0xFF831843), Color(0xFFA21C5B), Color(0xFF6B1238)];
  static const _rose = [Color(0xFFE8A598), Color(0xFFF2C4B8), Color(0xFFD4918F)];
  static const _cream = Color(0xFFFDECEE);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rimRect = Rect.fromCircle(center: center, radius: radius);

    // Rose-gold metallic rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(colors: [
          Color(0xFFF9D7CF),
          Color(0xFFB76E79),
          Color(0xFFF2C4B8),
          Color(0xFF8E4B57),
          Color(0xFFF9D7CF),
        ]).createShader(rimRect),
    );

    final inner = radius * 0.9;
    final innerRect = Rect.fromCircle(center: center, radius: inner);
    final n = labels.length;
    if (n == 0) return;

    final sweep = 2 * pi / n;
    final fill = Paint()..style = PaintingStyle.fill;
    final divider = Paint()
      ..color = const Color(0xFFF9D7CF).withOpacity(0.8)
      ..strokeWidth = n > 30 ? 0.6 : 1.2;
    final fontSize = n <= 6
        ? 17.0
        : n <= 12
            ? 14.0
            : n <= 24
                ? 11.0
                : n <= 40
                    ? 9.0
                    : 7.5;

    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * sweep;
      // Alternate berry / rose-gold. With an odd count the last slice would touch
      // two of the same colour, so it gets blush instead.
      final bool cream = n > 1 && n.isOdd && i == n - 1;
      final bool gold = !cream && i.isOdd;
      fill.color = cream ? _cream : (gold ? _rose[(i ~/ 2) % 3] : _berry[(i ~/ 2) % 3]);
      canvas.drawArc(innerRect, start, sweep, true, fill);
      if (n > 1) {
        canvas.drawLine(center, center + Offset(cos(start), sin(start)) * inner, divider);
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + sweep / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: _label(labels[i], n),
          style: TextStyle(
            color: (gold || cream) ? const Color(0xFF4A0D2B) : Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: inner * 0.66);
      tp.paint(canvas, Offset(inner * 0.94 - tp.width, -tp.height / 2));
      canvas.restore();
    }

    // Soft dome shading for depth.
    canvas.drawCircle(
      center,
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.10), Colors.transparent, Colors.black.withOpacity(0.22)],
          stops: const [0, 0.55, 1],
        ).createShader(innerRect),
    );

    // Rim studs.
    const studs = 24;
    final stud = Paint()..color = Colors.white.withOpacity(0.95);
    for (var k = 0; k < studs; k++) {
      final a = 2 * pi * k / studs;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * ((radius + inner) / 2), radius * 0.012 + 1, stud);
    }
  }

  static String _label(String name, int n) {
    final t = name.trim();
    return n > 24 ? t.split(RegExp(r'\s+')).first : t;
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => !listEquals(oldDelegate.labels, labels);
}

/// Gold pointer at 12 o'clock.
class WheelPointer extends StatelessWidget {
  const WheelPointer({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 40, height: 50, child: CustomPaint(painter: _PointerPainter()));
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 6, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF9D7CF), Color(0xFFB76E79)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
