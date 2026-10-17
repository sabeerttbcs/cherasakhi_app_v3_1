// Picks the browser implementation on web, a no-op stub everywhere else.
export 'web_notifier_stub.dart' if (dart.library.js_interop) 'web_notifier_web.dart';
