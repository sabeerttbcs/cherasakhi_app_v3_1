import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser Notification API for the CheraSakhi PWA.
bool get webNotificationsGranted {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false; // e.g. iOS Safari when not installed to the home screen
  }
}

Future<bool> requestWebNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> showWebNotification(String title, String body) async {
  if (!webNotificationsGranted) return;
  final options = web.NotificationOptions(
    body: body,
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: title,
  );
  try {
    // Desktop browsers allow page-created notifications…
    web.Notification(title, options);
  } catch (_) {
    // …Android Chrome / installed PWAs require the service worker.
    try {
      final reg = await web.window.navigator.serviceWorker.ready.toDart;
      await reg.showNotification(title, options).toDart;
    } catch (_) {}
  }
}
