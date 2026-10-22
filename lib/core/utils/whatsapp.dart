import 'package:url_launcher/url_launcher.dart';

import 'formatters.dart';

class WhatsAppLauncher {
  WhatsAppLauncher._();

  static String invitationMessage(
          {required String name, required String token}) =>
      'Hello ${name.trim()} 🌸\n\n'
      'You are invited to CheraSakhi. Create your password here:\n'
      'https://sakhi.sabeerlabs.com/?invite=$token\n\n'
      'This one-time invitation expires in 7 days.';

  /// Builds WhatsApp's recipient-specific Click to Chat URL.
  ///
  /// This deliberately requires a phone number, so invitation actions can
  /// never fall back to WhatsApp's recipient picker or a generic share flow.
  static String invitationUrl(
      {required String phone, required String message}) {
    final digits = whatsappDigits(phone);
    return Uri.https('wa.me', '/$digits', {'text': message}).toString();
  }

  static Future<bool> openInvitation(
      {required String phone, required String message}) async {
    if (!isValidPhone(phone)) return false;
    try {
      return await launchUrl(
        Uri.parse(invitationUrl(phone: phone, message: message)),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Opens WhatsApp via a `wa.me` deep link. Pass [phone] = null to let the
  /// user pick a chat / group (useful for broadcast reminders).
  static Future<bool> send({String? phone, required String message}) async {
    final uri = phone == null
        ? Uri.https('wa.me', '/', {'text': message})
        : Uri.parse(invitationUrl(phone: phone, message: message));
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String reminder({
    required String name,
    required String monthLabel,
    required num amount,
    required String groupName,
  }) =>
      'Hello $name 🌸\n\n'
      'Gentle reminder from *$groupName*: your Kuri installment of '
      '*${formatMoney(amount)}* for *$monthLabel* is still pending.\n\n'
      'Please pay before the Pamparam lucky draw so you stay eligible 🎡\n\n'
      'Thank you! 🙏';

  static String groupReminder({
    required List<String> names,
    required String monthLabel,
    required num amount,
    required String groupName,
  }) {
    final list = [
      for (var i = 0; i < names.length; i++) '${i + 1}. ${names[i]}'
    ].join('\n');
    return '📢 *$groupName* — Kuri reminder for *$monthLabel*\n\n'
        'Installment: *${formatMoney(amount)}*\n'
        'Pending (${names.length}):\n$list\n\n'
        'Only paid members are eligible for this month\'s Pamparam draw 🎡🙏';
  }
}
