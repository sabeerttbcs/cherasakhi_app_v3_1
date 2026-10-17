import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/usecases/quiz_evaluation.dart';

/// `MM:SS`, `HH:MM:SS`, or `2d 04:12:09`.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final days = d.inDays;
  final h = d.inHours % 24;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (days > 0) return '${days}d ${two(h)}:${two(m)}:${two(s)}';
  if (d.inHours > 0) return '${two(d.inHours)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

/// "08:04:12.347 PM" — millisecond precision for fastest-finger results.
String formatPreciseTime(DateTime t) =>
    '${DateFormat('hh:mm:ss').format(t)}.${t.millisecond.toString().padLeft(3, '0')} ${DateFormat('a').format(t)}';

/// "4m 12.347s"
String formatElapsed(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
  return m > 0 ? '${m}m $s.${ms}s' : '$s.${ms}s';
}

/// "Fri 17 Oct · 08:00 PM"
String formatSchedule(DateTime t) => DateFormat('EEE d MMM · hh:mm a').format(t);
String formatClock(DateTime t) => DateFormat('hh:mm a').format(t);

/// High-contrast style that renders Malayalam and English cleanly.
TextStyle quizTextStyle({
  double size = 16,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double height = 1.55,
}) =>
    GoogleFonts.notoSansMalayalam(fontSize: size, fontWeight: weight, color: color, height: height)
        .copyWith(fontFamilyFallback: [GoogleFonts.poppins().fontFamily!]);

/// Timer colours: calm teal → warm amber → urgent crimson.
class TimerColors {
  TimerColors._();

  static const calm = Color(0xFF0D9488);
  static const calmGlow = Color(0xFF2DD4BF);
  static const warning = Color(0xFFF59E0B);
  static const warningGlow = Color(0xFFFCD34D);
  static const critical = Color(0xFFDC2626);
  static const criticalGlow = Color(0xFFF87171);

  static Color main(TimerTone t) => switch (t) {
        TimerTone.calm => calm,
        TimerTone.warning => warning,
        TimerTone.critical => critical,
      };

  static Color glow(TimerTone t) => switch (t) {
        TimerTone.calm => calmGlow,
        TimerTone.warning => warningGlow,
        TimerTone.critical => criticalGlow,
      };
}
