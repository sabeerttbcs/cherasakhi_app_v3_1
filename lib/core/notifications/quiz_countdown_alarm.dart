import 'dart:async';

import 'package:flutter/services.dart';

import 'notification_service.dart';

/// Ticking audio + haptics for the final minute of a live quiz.
///
/// * At 60 s left: one "1 minute left" notification + heavy haptic.
/// * 59–10 s: soft tick every second.
/// * Last 10 s: sharp beep + stronger haptic every second.
///
/// ```dart
/// final _alarm = QuizCountdownAlarm();
/// _alarm.start(endsAt: quiz.endsAt, quizTitle: quiz.title);   // when the quiz screen opens
/// _alarm.stop();                                              // on submit / dispose
/// ```
class QuizCountdownAlarm {
  QuizCountdownAlarm({
    this.window = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long before the end the alarm starts.
  final Duration window;

  /// Pass a server-corrected clock if the quiz uses server time.
  final DateTime Function() _clock;

  Timer? _timer;
  int _lastSecond = -1;
  bool _warned = false;

  bool get isRunning => _timer != null;

  void start({required DateTime endsAt, String quizTitle = 'Live Quiz'}) {
    stop();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick(endsAt, quizTitle));
  }

  void _onTick(DateTime endsAt, String quizTitle) {
    final left = endsAt.difference(_clock());
    if (left <= Duration.zero) {
      stop();
      HapticFeedback.heavyImpact();
      return;
    }
    if (left > window) return;

    final second = left.inSeconds;
    if (second == _lastSecond) return;
    _lastSecond = second;

    if (!_warned) {
      _warned = true;
      HapticFeedback.heavyImpact();
      NotificationService.instance.alert(
        kind: AlertKind.info,
        title: '⏳ ഒരു മിനിറ്റ് മാത്രം ബാക്കി! (1 minute left)',
        body: '$quizTitle — please submit your answers',
        dedupeKey: 'final-minute:${endsAt.millisecondsSinceEpoch}',
      );
    }

    final urgent = second < 10;
    NotificationService.instance.tick(urgent: urgent);
    if (urgent) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastSecond = -1;
    _warned = false;
  }
}
