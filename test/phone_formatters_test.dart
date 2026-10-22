import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/core/utils/formatters.dart';

void main() {
  test('normalizes Indian numbers entered without a country code', () {
    expect(normalizePhone('98765 43210'), '+919876543210');
    expect(normalizePhone('09876543210'), '+919876543210');
  });

  test('preserves an explicitly entered international country code', () {
    expect(normalizePhone('+44 20 7946 0958'), '+442079460958');
    expect(normalizePhone('0049 30 123456'), '+4930123456');
    expect(normalizePhone('+1 (415) 555-0100'), '+14155550100');
  });

  test('produces WhatsApp digits without duplicating a country code', () {
    expect(whatsappDigits('9876543210'), '919876543210');
    expect(whatsappDigits('+919876543210'), '919876543210');
    expect(whatsappDigits('919876543210'), '919876543210');
    expect(whatsappDigits('+44 20 7946 0958'), '442079460958');
  });

  test('rejects too-short numbers but accepts international formats', () {
    expect(isValidPhone('123456789'), isFalse);
    expect(isValidPhone('+44 20 7946 0958'), isTrue);
    expect(isValidPhone('919876543210'), isTrue);
  });
}
