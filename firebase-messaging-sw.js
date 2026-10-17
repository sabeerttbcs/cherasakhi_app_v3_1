/* CheraSakhi — Firebase Cloud Messaging service worker (Web / PWA push).
 *
 * Place at:  web/firebase-messaging-sw.js   (copied to build/web/ by `flutter build web`)
 * Fill in the config below from: Firebase console → Project settings → Your apps → Web app.
 * These values are public identifiers, not secrets.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'YOUR_API_KEY',
  authDomain: 'YOUR_PROJECT.firebaseapp.com',
  projectId: 'YOUR_PROJECT',
  storageBucket: 'YOUR_PROJECT.appspot.com',
  messagingSenderId: 'YOUR_SENDER_ID',
  appId: 'YOUR_WEB_APP_ID',
});

const messaging = firebase.messaging();

// Runs when a push arrives while the app tab is closed / in the background.
// Messages that include a `notification` block are shown automatically by the
// SDK — only build our own for data-only messages, to avoid duplicates.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  return self.registration.showNotification(data.title || 'CheraSakhi', {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: data.key || undefined,      // same event replaces, never stacks
    vibrate: [200, 100, 200],
    data: { link: data.link || './' },
  });
});

// Tapping the notification focuses the open app, or opens it.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = (event.notification.data && event.notification.data.link) || './';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ('focus' in w) return w.focus();
      }
      return clients.openWindow(link);
    })
  );
});
