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

/// Orchestrates SSLCommerz gateway initiation via the server-side
/// `sslcommerz-init` Supabase Edge Function so store credentials never exist
/// in the mobile binary, with controlled sandbox simulation fallback when offline.
class SSLCommerzService {
  final SupabaseService? _injectedService;

  SSLCommerzService({SupabaseService? supabaseService})
      : _injectedService = supabaseService;

  SupabaseService get _supabaseService => _injectedService ?? SupabaseService();

  /// Initiates an SSLCommerz payment session through the server Edge Function.
  Future<SSLCommerzSessionResult> initiateSession({
    required String requestId,
    required double amount,
    required String customerName,
    required String customerPhone,
    String? quotationId,
    String paymentMethod = 'SSLCommerz-Online',
    String? customerEmail,
  }) async {
    final fallbackTranId =
        'SSLCZ-SANDBOX-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await _supabaseService.client.functions.invoke(
        'sslcommerz-init',
        body: {
          'request_id': requestId,
          if (quotationId != null && quotationId.isNotEmpty)
            'quotation_id': quotationId,
          'payment_method': paymentMethod,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          if (customerEmail != null && customerEmail.isNotEmpty)
            'customer_email': customerEmail,
          // Client hint only; authoritative amount is always read from DB quotation.
          'requested_amount': amount,
        },
      );

      if (response.status == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final gatewayUrl = data['gateway_page_url']?.toString() ?? '';
        final tranId =
            data['gateway_transaction_id']?.toString() ?? fallbackTranId;
        if (gatewayUrl.isNotEmpty) {
          return SSLCommerzSessionResult.success(
            gatewayPageUrl: gatewayUrl,
            sessionKey: data['session_key']?.toString() ?? '',
            transactionId: tranId,
          );
        }
      }

      final errMsg = (response.data is Map && response.data['error'] != null)
          ? response.data['error'].toString()
          : 'SSLCommerz Edge Function unavailable (HTTP ${response.status}).';
      return SSLCommerzSessionResult.fallback(
        transactionId: fallbackTranId,
        message: errMsg,
      );
    } catch (e) {
      return SSLCommerzSessionResult.fallback(
        transactionId: fallbackTranId,
        message: 'Could not reach SSLCommerz payment service ($e).',
      );
    }
  }

  /// Finalizes cash settlement cleanly via authenticated RPC (`confirm_cash_settlement`),
  /// or returns an authoritative error/completed record when verified by IPN.
  Future<Map<String, dynamic>> recordSettlement({
    required String requestId,
    required String quotationId,
    required double amount,
    required String paymentMethod,
    required String gatewayTransactionId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    if (paymentMethod.toLowerCase() == 'cash') {
      return await _supabaseService.confirmCashSettlement(
        requestId: requestId,
        quotationId: quotationId.isEmpty ? null : quotationId,
      );
    }

    // For gateway payments, completion happens server-side in `sslcommerz-ipn`;
    // check whether the transaction was already settled by the IPN webhook.
    final existing = await _supabaseService.client
        .from('transactions')
        .select()
        .eq('request_id', requestId)
        .eq('status', 'completed')
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing);
    }

    return {
      'request_id': requestId,
      'quotation_id': quotationId,
      'amount': amount,
      'payment_method': paymentMethod,
      'gateway_transaction_id': gatewayTransactionId,
      'status': 'pending_ipn_verification',
      ...?additionalMetadata,
    };
  }
}
