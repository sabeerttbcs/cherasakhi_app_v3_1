import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/core/utils/whatsapp.dart';

void main() {
  test('builds a recipient-specific Click to Chat URL', () {
    final url = WhatsAppLauncher.invitationUrl(
      phone: '+91 98765 43210',
      message: 'Hello CheraSakhi',
    );

    expect(url, startsWith('https://wa.me/919876543210?text='));
    expect(url, isNot(contains('wa.me/?text=')));
    expect(Uri.parse(url).queryParameters['text'], 'Hello CheraSakhi');
  });

  test('reuses the saved invitation token in the message', () {
    final message = WhatsAppLauncher.invitationMessage(
      name: 'Majida',
      token: 'saved-token',
    );

    expect(
        message, contains('https://sakhi.sabeerlabs.com/?invite=saved-token'));
  });
}
