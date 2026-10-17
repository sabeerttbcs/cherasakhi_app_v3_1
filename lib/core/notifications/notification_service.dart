import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'web_notifier.dart';

/// What kind of event an alert is about — decides the sound.
enum AlertKind { quizLive, winner, info }

/// CheraSakhi alerts: system notifications + audio chimes + countdown ticks.
///
/// * Android / iOS → `flutter_local_notifications`
/// * Web / PWA     → browser Notification API (see web_notifier_web.dart)
///
/// Usage:
/// ```dart
/// await NotificationService.instance.init();                    // main()
/// NotificationService.instance.requestPermissionAndRegister(...); // after login
/// NotificationService.instance.alert(kind: AlertKind.winner, ...);
/// ```
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const channelId = 'cherasakhi_alerts';
  static const channelName = 'CheraSakhi alerts';
  static const channelDescription = 'Live quiz launches, Pamparam winners and reminders';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF4A0E2E), // deep berry accent
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final AudioPlayer _alertPlayer = AudioPlayer();
  final List<AudioPlayer> _tickPool = <AudioPlayer>[];
  final Set<String> _alreadyAlerted = <String>{};

  bool _initialised = false;
  int _notificationId = 0;
  int _tickCursor = 0;

  /// Sound on/off switch (notifications still appear when muted).
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // ───────────────────────────── setup ─────────────────────────────

  /// Safe to call more than once. Does NOT show a permission prompt.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    if (_isMobile) {
      try {
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                channelId,
                channelName,
                description: channelDescription,
                importance: Importance.high,
              ),
            );
      } catch (e) {
        debugPrint('NotificationService: local init failed: $e');
      }
    }

  }

  /// Whether the browser already granted permission (web only; mobile → false).
  bool get webPermissionGranted => kIsWeb && webNotificationsGranted;

  /// Shows the local/browser notification permission prompt.
  /// On the web call this from a button tap (Safari/iOS require a user gesture).
  Future<bool> requestPermissionAndRegister({
    required String uid,
    required FirebaseFirestore db,
  }) async {
    await init();
    var granted = false;
    try {
      if (kIsWeb) {
        granted = await requestWebNotificationPermission();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        granted = await _local
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _local
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('NotificationService: permission request failed: $e');
    }
    return granted;
  }

  /// Push-token cleanup is intentionally a no-op: CheraSakhi uses only
  /// Authentication and Firestore, with local/browser alerts where available.
  Future<void> unregister(FirebaseFirestore db) async {}

  // ───────────────────────────── alerts ─────────────────────────────

  /// Shows a system notification and plays the matching chime.
  ///
  /// [dedupeKey] stops the same event alerting twice (e.g. once from the
  /// Firestore listener and once from an FCM push).
  Future<void> alert({
    required AlertKind kind,
    required String title,
    required String body,
    String? dedupeKey,
  }) async {
    if (dedupeKey != null && !_alreadyAlerted.add('${kind.name}:$dedupeKey')) return;
    await init();
    unawaited(playSound(kind == AlertKind.winner ? 'sounds/win.wav' : 'sounds/chime.wav'));
    try {
      if (kIsWeb) {
        await showWebNotification(title, body);
      } else if (_isMobile) {
        await _local.show(_notificationId++ & 0x7fffffff, title, body, _details);
      }
    } catch (e) {
      debugPrint('NotificationService: show failed: $e');
    }
  }

  // ───────────────────────────── audio ─────────────────────────────

  /// Plays a bundled asset (path relative to `assets/`).
  /// Browsers block audio until the user has tapped the page once — errors are ignored.
  Future<void> playSound(String asset, {double volume = 0.9}) async {
    if (muted.value) return;
    try {
      await _alertPlayer.stop();
      await _alertPlayer.play(AssetSource(asset), volume: volume);
    } catch (e) {
      debugPrint('NotificationService: audio blocked/failed: $e');
    }
  }

  /// Short countdown tick; [urgent] plays the sharper beep (last 10 seconds).
  void tick({bool urgent = false}) {
    if (muted.value) return;
    if (_tickPool.isEmpty) {
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop).ignore();
        _tickPool.add(p);
      }
    }
    final player = _tickPool[_tickCursor++ % _tickPool.length];
    player
        .play(
          AssetSource(urgent ? 'sounds/beep.wav' : 'sounds/tick.wav'),
          volume: urgent ? 0.85 : 0.6,
          mode: PlayerMode.lowLatency,
        )
        .ignore();
  }

  Future<void> dispose() async {
    await _alertPlayer.dispose();
    for (final p in _tickPool) {
      await p.dispose();
    }
    _tickPool.clear();
  }
}
