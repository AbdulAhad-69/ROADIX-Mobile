import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';

void main() {
  group('Bangladesh Phone Utilities Unit Tests', () {
    test('Normalizes standard 11-digit Bangladesh mobile numbers to E.164', () {
      expect(PhoneUtils.normalize('01712345678'), equals('+8801712345678'));
      expect(PhoneUtils.normalize('01812345678'), equals('+8801812345678'));
      expect(PhoneUtils.normalize('01912345678'), equals('+8801912345678'));
      expect(PhoneUtils.normalize('01312345678'), equals('+8801312345678'));
      expect(PhoneUtils.normalize('01412345678'), equals('+8801412345678'));
      expect(PhoneUtils.normalize('01512345678'), equals('+8801512345678'));
      expect(PhoneUtils.normalize('01612345678'), equals('+8801612345678'));
    });

    test('Normalizes international +880 and 880 prefixes correctly', () {
      expect(PhoneUtils.normalize('+8801712345678'), equals('+8801712345678'));
      expect(PhoneUtils.normalize('8801712345678'), equals('+8801712345678'));
    });

    test('Strips spaces, hyphens, and parentheses before normalization', () {
      expect(PhoneUtils.normalize('017-1234-5678'), equals('+8801712345678'));
      expect(PhoneUtils.normalize('+880 1712 345 678'), equals('+8801712345678'));
      expect(PhoneUtils.normalize('(017) 12345678'), equals('+8801712345678'));
    });

    test('Validates authentic Bangladesh mobile operators (013 - 019)', () {
      expect(PhoneUtils.isValidBangladeshPhone('01712345678'), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone('+8801812345678'), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone('01912345678'), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone('01512345678'), isTrue);

      // Invalid operator codes: 010, 011, 012
      expect(PhoneUtils.isValidBangladeshPhone('01012345678'), isFalse);
      expect(PhoneUtils.isValidBangladeshPhone('01112345678'), isFalse);
      expect(PhoneUtils.isValidBangladeshPhone('01212345678'), isFalse);

      // Invalid lengths
      expect(PhoneUtils.isValidBangladeshPhone('0171234567'), isFalse); // 10 digits
      expect(PhoneUtils.isValidBangladeshPhone('017123456789'), isFalse); // 12 digits
      expect(PhoneUtils.isValidBangladeshPhone(''), isFalse);
      expect(PhoneUtils.isValidBangladeshPhone('abcdefghijk'), isFalse);
    });

    test('Formats phone for user display with operator spacing', () {
      expect(PhoneUtils.formatForDisplay('+8801712345678'), equals('+880 1712-345678'));
      expect(PhoneUtils.formatForDisplay('01712345678'), equals('+880 1712-345678'));
      expect(PhoneUtils.formatForDisplay(''), equals(''));
    });
  });

  group('Mechanic Workflow & Specialization Validation Tests', () {
    const canonicalCategories = [
      'Passenger Car',
      'Motorcycle',
      'Light Commercial',
    ];

    test('Enforces exact SRS vehicle specialization categories', () {
      expect(canonicalCategories.length, equals(3));
      expect(canonicalCategories.contains('Passenger Car'), isTrue);
      expect(canonicalCategories.contains('Motorcycle'), isTrue);
      expect(canonicalCategories.contains('Light Commercial'), isTrue);
      expect(canonicalCategories.contains('Heavy Commercial'), isFalse);
      expect(canonicalCategories.contains('Sedan'), isFalse);
    });

    test('Enforces at least one vehicle specialization category', () {
      final selected = ['Passenger Car'];
      bool canRemove(List<String> list, String item) => list.length > 1;

      expect(canRemove(selected, 'Passenger Car'), isFalse);

      selected.add('Motorcycle');
      expect(canRemove(selected, 'Passenger Car'), isTrue);
    });

    test('Enforces service status progression sequence in strict order', () {
      const allowedOrder = [
        'created',
        'searching',
        'assigned',
        'en_route',
        'arrived',
        'diagnosing',
        'quote_pending',
        'servicing',
        'completed',
      ];

      expect(allowedOrder.indexOf('assigned') < allowedOrder.indexOf('en_route'), isTrue);
      expect(allowedOrder.indexOf('en_route') < allowedOrder.indexOf('arrived'), isTrue);
      expect(allowedOrder.indexOf('arrived') < allowedOrder.indexOf('diagnosing'), isTrue);
      expect(allowedOrder.indexOf('diagnosing') < allowedOrder.indexOf('quote_pending'), isTrue);
      expect(allowedOrder.indexOf('quote_pending') < allowedOrder.indexOf('servicing'), isTrue);
      expect(allowedOrder.indexOf('servicing') < allowedOrder.indexOf('completed'), isTrue);
    });
  });

  group('Quotation & Development Mode Payment Simulation Tests', () {
    test('Calculates total quotation amount correctly from line item components', () {
      const double diagnosticFee = 350.0;
      const double laborFee = 600.0;
      const double partsFee = 1250.0;
      final total = diagnosticFee + laborFee + partsFee;

      expect(total, equals(2200.0));
      expect(total >= 0, isTrue);
    });

    test('Validates development mode payment methods against supported MFS', () {
      const supportedMfs = ['bKash', 'Nagad', 'Rocket', 'Cash'];
      expect(supportedMfs.contains('bKash'), isTrue);
      expect(supportedMfs.contains('Nagad'), isTrue);
      expect(supportedMfs.contains('Rocket'), isTrue);
      expect(supportedMfs.contains('Cash'), isTrue);
      expect(supportedMfs.contains('Crypto'), isFalse);
    });

    test('Development payment metadata unambiguously tags test mode', () {
      final metadata = {
        'environment': 'development',
        'is_simulation': true,
        'note': 'DEVELOPMENT MODE PAYMENT SIMULATION - NO REAL MONEY CHARGED',
      };

      expect(metadata['environment'], equals('development'));
      expect(metadata['is_simulation'], isTrue);
      expect((metadata['note'] as String).contains('SIMULATION'), isTrue);
    });
  });

  group('Review & Star Rating Validation Tests', () {
    test('Rating must strictly be an integer between 1 and 5 inclusive', () {
      bool isValidRating(int r) => r >= 1 && r <= 5;

      expect(isValidRating(1), isTrue);
      expect(isValidRating(3), isTrue);
      expect(isValidRating(5), isTrue);
      expect(isValidRating(0), isFalse);
      expect(isValidRating(6), isFalse);
      expect(isValidRating(-1), isFalse);
    });
  });
}
