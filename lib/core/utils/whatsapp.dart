import 'package:url_launcher/url_launcher.dart';

import 'formatters.dart';

class WhatsAppLauncher {
  WhatsAppLauncher._();

  /// Opens WhatsApp via a `wa.me` deep link. Pass [phone] = null to let the
  /// user pick a chat / group (useful for broadcast reminders).
  static Future<bool> send({String? phone, required String message}) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
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
    final list = [for (var i = 0; i < names.length; i++) '${i + 1}. ${names[i]}'].join('\n');
    return '📢 *$groupName* — Kuri reminder for *$monthLabel*\n\n'
        'Installment: *${formatMoney(amount)}*\n'
        'Pending (${names.length}):\n$list\n\n'
        'Only paid members are eligible for this month\'s Pamparam draw 🎡🙏';
  }
}
