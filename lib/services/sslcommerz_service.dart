import 'dart:convert';
import 'dart:io';
import '../src/core/config/app_config.dart';
import 'supabase_service.dart';

/// Result container for an SSLCommerz gateway session initiation.
class SSLCommerzSessionResult {
  final bool isSuccess;
  final String? gatewayPageUrl;
  final String? sessionKey;
  final String transactionId;
  final String? errorMessage;
  final bool isSimulatedFallback;

  const SSLCommerzSessionResult({
    required this.isSuccess,
    this.gatewayPageUrl,
    this.sessionKey,
    required this.transactionId,
    this.errorMessage,
    this.isSimulatedFallback = false,
  });

  factory SSLCommerzSessionResult.success({
    required String gatewayPageUrl,
    required String sessionKey,
    required String transactionId,
  }) {
    return SSLCommerzSessionResult(
      isSuccess: true,
      gatewayPageUrl: gatewayPageUrl,
      sessionKey: sessionKey,
      transactionId: transactionId,
    );
  }

  factory SSLCommerzSessionResult.fallback({
    required String transactionId,
    String? message,
  }) {
    return SSLCommerzSessionResult(
      isSuccess: false,
      transactionId: transactionId,
      errorMessage: message,
      isSimulatedFallback: true,
    );
  }
}

/// Service orchestrating SSLCommerz Payment Gateway sessions in Sandbox mode
/// with automatic in-app simulation fallback for offline development.
class SSLCommerzService {
  final SupabaseService _supabaseService;

  SSLCommerzService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  /// Initiates an SSLCommerz v4 payment gateway session.
  Future<SSLCommerzSessionResult> initiateSession({
    required String requestId,
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) async {
    final tranId = 'SSLCZ-SANDBOX-${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, String>{
      'store_id': AppConfig.sslcommerzStoreId,
      'store_passwd': AppConfig.sslcommerzStorePassword,
      'total_amount': amount.toStringAsFixed(2),
      'currency': 'BDT',
      'tran_id': tranId,
      'success_url': 'https://roadix.app/payment/success',
      'fail_url': 'https://roadix.app/payment/fail',
      'cancel_url': 'https://roadix.app/payment/cancel',
      'ipn_url': 'https://roadix.app/payment/ipn',
      'cus_name': customerName.isNotEmpty ? customerName : 'Roadside Motorist',
      'cus_email': customerEmail ?? 'motorist@roadix.app',
      'cus_phone': customerPhone.isNotEmpty ? customerPhone : '+8801700000000',
      'cus_add1': 'Dhaka, Bangladesh',
      'cus_city': 'Dhaka',
      'cus_country': 'Bangladesh',
      'shipping_method': 'NO',
      'product_name': 'Emergency Roadside Assistance & Breakdown Service',
      'product_category': 'Automotive Rescue',
      'product_profile': 'general',
    };

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse(AppConfig.sslcommerzSessionUrl);
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );

      final formBody = payload.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      request.write(formBody);
      final response = await request.close();

      if (response.statusCode == 200) {
        final respString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(respString) as Map<String, dynamic>;

        if (data['status'] == 'SUCCESS' && data['GatewayPageURL'] != null) {
          return SSLCommerzSessionResult.success(
            gatewayPageUrl: data['GatewayPageURL'] as String,
            sessionKey: data['sessionkey'] as String? ?? '',
            transactionId: tranId,
          );
        }
      }

      return SSLCommerzSessionResult.fallback(
        transactionId: tranId,
        message: 'SSLCommerz gateway session status unsuccessful.',
      );
    } catch (e) {
      // Offline, network failure, or sandbox server maintenance fallback
      return SSLCommerzSessionResult.fallback(
        transactionId: tranId,
        message: 'Could not connect to SSLCommerz Sandbox API ($e).',
      );
    } finally {
      client.close();
    }
  }

  /// Finalizes and records the settled transaction in Supabase.
  Future<Map<String, dynamic>> recordSettlement({
    required String requestId,
    required String quotationId,
    required double amount,
    required String paymentMethod, // 'SSLCommerz-bKash', 'SSLCommerz-Nagad', 'SSLCommerz-Card'
    required String gatewayTransactionId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final metadata = {
      'environment': 'sandbox',
      'gateway': 'SSLCommerz',
      'store_id': AppConfig.sslcommerzStoreId,
      'is_sandbox': AppConfig.sslcommerzIsSandbox,
      'settled_at': DateTime.now().toUtc().toIso8601String(),
      ...?additionalMetadata,
    };

    final inserted = await _supabaseService.client.from('transactions').insert({
      'request_id': requestId,
      'quotation_id': quotationId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': 'completed',
      'gateway_transaction_id': gatewayTransactionId,
      'metadata': metadata,
    }).select().single();

    // Ensure parent request is marked completed
    await _supabaseService.updateServiceStatus(
      requestId: requestId,
      status: 'completed',
    );

    return Map<String, dynamic>.from(inserted);
  }
}
