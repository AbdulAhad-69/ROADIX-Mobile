import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';

/// Outcome returned by [SslcommerzCheckoutScreen] or URL callback classifier.
enum SslcommerzOutcome {
  success,
  failed,
  cancelled,
}

/// Decision computed for any navigation URL observed inside SSLCommerz WebView.
enum SslcommerzNavigationAction {
  navigate,
  completeSuccess,
  completeFailed,
  completeCancelled,
  block,
}

/// Parsed URL classification result with extracted gateway parameters (`tran_id`, `val_id`).
class SslcommerzUrlDecision {
  final SslcommerzNavigationAction action;
  final String? tranId;
  final String? valId;
  final String? reason;

  const SslcommerzUrlDecision({
    required this.action,
    this.tranId,
    this.valId,
    this.reason,
  });
}

/// Result returned when [SslcommerzCheckoutScreen] pops back to `DispatchScreen`.
class SslcommerzCheckoutResult {
  final SslcommerzOutcome outcome;
  final String? tranId;
  final String? valId;
  final String? message;

  const SslcommerzCheckoutResult({
    required this.outcome,
    this.tranId,
    this.valId,
    this.message,
  });
}

/// Classifies gateway redirects deterministically so callback handling can be
/// unit-tested without a native WebView plugin.
SslcommerzUrlDecision classifySslcommerzUrl(
  String rawUrl, {
  String callbackScheme = 'io.supabase.roadix',
  String callbackHost = 'payment-callback',
}) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || uri.scheme.isEmpty) {
    return const SslcommerzUrlDecision(
      action: SslcommerzNavigationAction.block,
      reason: 'Malformed URL',
    );
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == callbackScheme.toLowerCase() &&
      uri.host.toLowerCase() == callbackHost.toLowerCase()) {
    final status = (uri.queryParameters['status'] ?? '').toLowerCase().trim();
    final tranId = uri.queryParameters['tran_id']?.trim();
    final valId = uri.queryParameters['val_id']?.trim();
    return switch (status) {
      'success' || 'valid' || 'validated' => SslcommerzUrlDecision(
          action: SslcommerzNavigationAction.completeSuccess,
          tranId: tranId,
          valId: valId,
        ),
      'cancelled' || 'cancel' => SslcommerzUrlDecision(
          action: SslcommerzNavigationAction.completeCancelled,
          tranId: tranId,
          reason: 'Payment cancelled by customer.',
        ),
      _ => SslcommerzUrlDecision(
          action: SslcommerzNavigationAction.completeFailed,
          tranId: tranId,
          reason: uri.queryParameters['error'] ??
              'SSLCommerz reported a failed transaction.',
        ),
    };
  }

  if (scheme == 'https' || scheme == 'http') {
    return const SslcommerzUrlDecision(
      action: SslcommerzNavigationAction.navigate,
    );
  }

  return SslcommerzUrlDecision(
    action: SslcommerzNavigationAction.block,
    reason: 'Blocked unsafe URI scheme: $scheme',
  );
}

/// Interactive in-app WebView presenting SSLCommerz Gateway checkout (`GatewayPageURL`).
class SslcommerzCheckoutScreen extends StatefulWidget {
  final String gatewayPageUrl;
  final String transactionId;
  final double amount;

  const SslcommerzCheckoutScreen({
    super.key,
    required this.gatewayPageUrl,
    required this.transactionId,
    required this.amount,
  });

  @override
  State<SslcommerzCheckoutScreen> createState() =>
      _SslcommerzCheckoutScreenState();
}

class _SslcommerzCheckoutScreenState extends State<SslcommerzCheckoutScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _hasCompleted = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.porcelainBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100.0);
          },
          onPageStarted: (_) {
            if (mounted && _loadError != null) {
              setState(() => _loadError = null);
            }
          },
          onWebResourceError: (err) {
            if (_hasCompleted) return;
            if (err.isForMainFrame == true && mounted) {
              setState(() => _loadError = err.description);
            }
          },
          onNavigationRequest: (request) {
            final decision = classifySslcommerzUrl(request.url);
            switch (decision.action) {
              case SslcommerzNavigationAction.completeSuccess:
                _finish(
                  SslcommerzCheckoutResult(
                    outcome: SslcommerzOutcome.success,
                    tranId: decision.tranId ?? widget.transactionId,
                    valId: decision.valId,
                  ),
                );
                return NavigationDecision.prevent;
              case SslcommerzNavigationAction.completeFailed:
                _finish(
                  SslcommerzCheckoutResult(
                    outcome: SslcommerzOutcome.failed,
                    tranId: decision.tranId ?? widget.transactionId,
                    message: decision.reason,
                  ),
                );
                return NavigationDecision.prevent;
              case SslcommerzNavigationAction.completeCancelled:
                _finish(
                  SslcommerzCheckoutResult(
                    outcome: SslcommerzOutcome.cancelled,
                    tranId: decision.tranId ?? widget.transactionId,
                    message: decision.reason,
                  ),
                );
                return NavigationDecision.prevent;
              case SslcommerzNavigationAction.block:
                return NavigationDecision.prevent;
              case SslcommerzNavigationAction.navigate:
                return NavigationDecision.navigate;
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.gatewayPageUrl));
  }

  void _finish(SslcommerzCheckoutResult result) {
    if (_hasCompleted) return;
    _hasCompleted = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish(
            SslcommerzCheckoutResult(
              outcome: SslcommerzOutcome.cancelled,
              tranId: widget.transactionId,
              message: 'Checkout closed before completion.',
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.porcelainBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel checkout',
            onPressed: () => _finish(
              SslcommerzCheckoutResult(
                outcome: SslcommerzOutcome.cancelled,
                tranId: widget.transactionId,
                message: 'Checkout cancelled.',
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SSLCommerz Checkout',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                '৳ ${widget.amount.toStringAsFixed(0)} • Secured Gateway',
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.lock_outline,
                color: AppColors.emeraldDark,
                size: 18,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress < 1.0
                ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 3,
                    backgroundColor: AppColors.slateBorder,
                    color: AppColors.caliperCrimson,
                  )
                : const Divider(height: 1),
          ),
        ),
        body: _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: AppColors.caliperCrimson,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load SSLCommerz gateway',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _loadError = null);
                          _controller.loadRequest(
                            Uri.parse(widget.gatewayPageUrl),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
