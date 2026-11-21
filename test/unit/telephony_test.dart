import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';

void main() {
  group('Telephony & Dialer Intent Unit Tests', () {
    test('createTelUri correctly formats emergency 999', () {
      final uri = PhoneUtils.createTelUri('999');
      expect(uri.scheme, equals('tel'));
      expect(uri.path, equals('999'));
      expect(uri.toString(), equals('tel:999'));
    });

    test('createTelUri correctly normalizes Bangladesh standard mobile numbers', () {
      final uri = PhoneUtils.createTelUri('01712345678');
      expect(uri.scheme, equals('tel'));
      expect(uri.path, equals('+8801712345678'));
      expect(uri.toString(), equals('tel:+8801712345678'));
    });

    test('createTelUri handles already-normalized +880 numbers with formatting', () {
      final uri = PhoneUtils.createTelUri('+880 1812-345678');
      expect(uri.scheme, equals('tel'));
      expect(uri.path, equals('+8801812345678'));
      expect(uri.toString(), equals('tel:+8801812345678'));
    });

    test('createTelUri handles unformatted 10-digit input', () {
      final uri = PhoneUtils.createTelUri('1912345678');
      expect(uri.scheme, equals('tel'));
      expect(uri.path, equals('+8801912345678'));
      expect(uri.toString(), equals('tel:+8801912345678'));
    });

    test('createTelUri falls back gracefully on arbitrary contact numbers', () {
      final uri = PhoneUtils.createTelUri('16123');
      expect(uri.scheme, equals('tel'));
      expect(uri.path, equals('+88016123'));
    });
  });
}
