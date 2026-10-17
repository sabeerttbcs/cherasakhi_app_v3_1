/// Non-web platforms: browser notifications don't exist.
bool get webNotificationsGranted => false;

Future<bool> requestWebNotificationPermission() async => false;

Future<void> showWebNotification(String title, String body) async {}
