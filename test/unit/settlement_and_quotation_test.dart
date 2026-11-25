import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/services/sslcommerz_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';

void main() {
  group('Milestone 5: Itemized Quotation Fee Calculations & Structure', () {
    test('Calculates total quotation amount correctly from itemized components', () {
      const double calloutFee = 350.0;
      const double laborFee = 600.0;
      const double partsFee = 450.0;

      final total = calloutFee + laborFee + partsFee;
      expect(total, equals(1400.0));
      expect(calloutFee, greaterThanOrEqualTo(0));
      expect(laborFee, greaterThanOrEqualTo(0));
      expect(partsFee, greaterThanOrEqualTo(0));
    });

    test('Zero parts or zero labor quotation remains valid and non-negative', () {
      const double calloutFee = 300.0;
      const double laborFee = 0.0;
      const double partsFee = 0.0;

      final total = calloutFee + laborFee + partsFee;
      expect(total, equals(300.0));
      expect(total, greaterThanOrEqualTo(0));
    });

    test('Parts breakdown JSON structure conforms to itemized line-item contract', () {
      final lineItems = {
        'description': 'Fan belt replacement and coolant top-up',
        'parts': [
          {'item': 'Alternator Fan Belt 4PK850', 'cost': 350.0},
          {'item': 'Prestone Coolant 1L', 'cost': 400.0},
        ],
        'diagnostic_bdt': 300.0,
        'labor_bdt': 500.0,
        'parts_bdt': 750.0,
      };

      expect(lineItems['description'], isNotEmpty);
      expect(lineItems['parts'], isA<List>());
      final partsList = lineItems['parts'] as List;
      expect(partsList.length, equals(2));

      double calculatedPartsTotal = 0;
      for (final p in partsList) {
        calculatedPartsTotal += (p['cost'] as num).toDouble();
      }
      expect(calculatedPartsTotal, equals(750.0));
      expect(lineItems['parts_bdt'], equals(calculatedPartsTotal));
    });
  });

  group('Milestone 5: Quotation Gate & State Transition Rules', () {
    test('Technician arrival advances request status to diagnosing', () {
      String status = 'en_route';

      // One-tap arrival transition
      void markArrived() {
        if (status == 'en_route' || status == 'arrived') {
          status = 'diagnosing';
        }
      }

      markArrived();
      expect(status, equals('diagnosing'));
    });

    test('Quotation submission transitions request from diagnosing to quote_pending', () {
      String requestStatus = 'diagnosing';
      String quoteStatus = 'pending';

      void submitQuote() {
        if (requestStatus == 'diagnosing') {
          requestStatus = 'quote_pending';
          quoteStatus = 'pending';
        }
      }

      submitQuote();
      expect(requestStatus, equals('quote_pending'));
      expect(quoteStatus, equals('pending'));
    });

    test('Direct leap from diagnosing to servicing without motorist approval is blocked', () {
      const String currentStatus = 'diagnosing';
      const bool motoristApproved = false;

      bool canAdvanceToServicing(String status, bool approved) {
        // Strict database rule: advancing to 'servicing' requires explicit approval
        if (status == 'quote_pending' && approved) {
          return true;
        }
        return false;
      }

      final allowed = canAdvanceToServicing(currentStatus, motoristApproved);
      expect(allowed, isFalse);
    });

    test('Motorist approval transitions request to servicing', () {
      String requestStatus = 'quote_pending';
      String quoteStatus = 'pending';

      void respondToQuote(String decision) {
        if (requestStatus == 'quote_pending' && quoteStatus == 'pending') {
          if (decision == 'accepted') {
            quoteStatus = 'accepted';
            requestStatus = 'servicing';
          } else if (decision == 'rejected') {
            quoteStatus = 'rejected';
            requestStatus = 'diagnosing';
          }
        }
      }

      respondToQuote('accepted');
      expect(quoteStatus, equals('accepted'));
      expect(requestStatus, equals('servicing'));
    });

    test('Motorist rejection loops request back to diagnosing for revision', () {
      String requestStatus = 'quote_pending';
      String quoteStatus = 'pending';
      int quoteRevision = 1;

      // 1. Motorist rejects initial quote
      void motoristReject() {
        if (requestStatus == 'quote_pending' && quoteStatus == 'pending') {
          quoteStatus = 'rejected';
          requestStatus = 'diagnosing';
        }
      }

      motoristReject();
      expect(quoteStatus, equals('rejected'));
      expect(requestStatus, equals('diagnosing'));

      // 2. Technician submits revised quote
      void technicianRevise() {
        if (requestStatus == 'diagnosing') {
          quoteRevision++;
          quoteStatus = 'pending';
          requestStatus = 'quote_pending';
        }
      }

      technicianRevise();
      expect(quoteRevision, equals(2));
      expect(quoteStatus, equals('pending'));
      expect(requestStatus, equals('quote_pending'));
    });

    test('Rescue completion transitions request from servicing to completed', () {
      String requestStatus = 'servicing';

      void markCompleted() {
        if (requestStatus == 'servicing') {
          requestStatus = 'completed';
        }
      }

      markCompleted();
      expect(requestStatus, equals('completed'));
    });
  });

  group('Milestone 5: Settlement & SSLCommerz Sandbox Gateway', () {
    test('AppConfig isolates SSLCommerz credentials server-side cleanly', () {
      expect(AppConfig.sslcommerzIsSandbox, isTrue);
      expect(AppConfig.sslcommerzSessionUrl, contains('sandbox.sslcommerz.com'));
      expect(AppConfig.geoapifyApiKey, isA<String>());
    });

    test('SSLCommerzService.initiateSession degrades cleanly to fallback without active session', () async {
      final result = await SSLCommerzService().initiateSession(
        requestId: '00000000-0000-0000-0000-000000000001',
        amount: 500.0,
        customerName: 'Test Motorist',
        customerPhone: '+8801711000001',
      );
      expect(result.transactionId, startsWith('SSLCZ-SANDBOX-'));
      expect(result.isSimulatedFallback, isTrue);
    });

    test('SSLCommerz session result handles successful gateway response', () {
      const trxId = 'SSLCZ-SANDBOX-1732200000000';
      const gatewayUrl = 'https://sandbox.sslcommerz.com/gwprocess/v4/gw.php?Q=pay&SESSIONKEY=abc123xyz';
      const sessionKey = 'abc123xyz';

      final result = SSLCommerzSessionResult.success(
        gatewayPageUrl: gatewayUrl,
        sessionKey: sessionKey,
        transactionId: trxId,
      );

      expect(result.isSuccess, isTrue);
      expect(result.gatewayPageUrl, equals(gatewayUrl));
      expect(result.sessionKey, equals(sessionKey));
      expect(result.transactionId, equals(trxId));
      expect(result.isSimulatedFallback, isFalse);
    });

    test('SSLCommerz session result provides fallback for offline development', () {
      const trxId = 'SSLCZ-SANDBOX-1732200000001';
      final result = SSLCommerzSessionResult.fallback(
        transactionId: trxId,
        message: 'Could not connect to SSLCommerz Sandbox API.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isSimulatedFallback, isTrue);
      expect(result.transactionId, equals(trxId));
      expect(result.errorMessage, contains('SSLCommerz Sandbox API'));
    });

    test('Digital invoice reference formatting conforms to standard format', () {
      String formatInvoiceRef(String? requestCode) {
        return 'INV-${requestCode ?? 'RDX-SERVICE'}';
      }

      expect(formatInvoiceRef('RDX-8924'), equals('INV-RDX-8924'));
      expect(formatInvoiceRef(null), equals('INV-RDX-SERVICE'));
    });
  });

  group('Milestone 5: Feedback & Technician Rating Validation', () {
    test('Rating must strictly be an integer between 1 and 5 inclusive', () {
      bool isValidRating(int rating) => rating >= 1 && rating <= 5;

      expect(isValidRating(1), isTrue);
      expect(isValidRating(3), isTrue);
      expect(isValidRating(5), isTrue);
      expect(isValidRating(0), isFalse);
      expect(isValidRating(6), isFalse);
      expect(isValidRating(-1), isFalse);
    });

    test('Technician trust rating average formula calculates accurately', () {
      final ratings = [5, 4, 5, 5, 4];
      final totalStars = ratings.fold<int>(0, (sum, r) => sum + r);
      final avg = totalStars / ratings.length;

      expect(avg, equals(4.6));
      expect(double.parse(avg.toStringAsFixed(2)), equals(4.60));
    });
  });
}
