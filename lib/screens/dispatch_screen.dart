import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class DispatchScreen extends StatefulWidget {
  final String selectedFault;
  final String vehicleType;
  final String licensePlate;
  final List<String> symptoms;
  final bool isHighPriority;
  final double breakdownLat;
  final double breakdownLng;
  final String breakdownAddress;
  final String diagnosticNotes;
  final String? existingRequestId;

  const DispatchScreen({
    super.key,
    required this.selectedFault,
    required this.vehicleType,
    required this.licensePlate,
    required this.symptoms,
    required this.isHighPriority,
    this.breakdownLat = 23.8759,
    this.breakdownLng = 90.3795,
    this.breakdownAddress = 'Dhaka Region • Roadside Position',
    this.diagnosticNotes = '',
    this.existingRequestId,
  });

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

enum DispatchPhase {
  submitting,
  searching,
  offered,
  assigned,
  exhausted,
  cancelled,
  error,
}

class _DispatchScreenState extends State<DispatchScreen>
    with SingleTickerProviderStateMixin {
  DispatchPhase _phase = DispatchPhase.submitting;
  late AnimationController _sonarController;

  String? _requestId;
  String? _requestCode;
  double _searchRadiusKm = 5.0;
  int _offerCountdown = 45;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  String? _assignedMechanicId;
  Map<String, dynamic>? _assignedMechanic;
  String? _candidateWorkshopName;
  String? _errorMessage;

  String _currentServiceStatus = 'searching';
  Map<String, dynamic>? _activeQuotation;
  bool _paymentDone = false;
  StreamSubscription? _statusSubscription;
  Timer? _assignedPollTimer;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    if (widget.existingRequestId != null) {
      _requestId = widget.existingRequestId;
      _resumeExistingRequest();
    } else {
      _createAndDispatch();
    }
  }

  @override
  void dispose() {
    _sonarController.dispose();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _assignedPollTimer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // DISPATCH ENGINE INTEGRATION
  // --------------------------------------------------------------------------

  Future<void> _createAndDispatch() async {
    setState(() {
      _phase = DispatchPhase.submitting;
      _errorMessage = null;
    });

    try {
      // Guard against duplicate active requests: check if in-flight active request exists
      final existing = await _supabaseService.getActiveServiceRequest();
      if (existing != null && mounted) {
        final existingStatus = existing['status'] as String?;
        if (existingStatus == 'searching' ||
            existingStatus == 'assigned' ||
            existingStatus == 'en_route' ||
            existingStatus == 'arrived' ||
            existingStatus == 'diagnosing' ||
            existingStatus == 'quote_pending' ||
            existingStatus == 'servicing') {
          _requestId = existing['id'] as String?;
          await _resumeExistingRequest();
          return;
        }
      }

      final result = await _supabaseService.createServiceRequest(
        breakdownLat: widget.breakdownLat,
        breakdownLng: widget.breakdownLng,
        breakdownAddress: widget.breakdownAddress,
        vehicleType: widget.vehicleType,
        licensePlate: widget.licensePlate,
        faultType: widget.selectedFault,
        symptoms: widget.symptoms,
        diagnosticNotes: widget.diagnosticNotes,
        isHighPriority: widget.isHighPriority,
      );

      _requestId = result['id'] as String?;
      _requestCode = result['request_code'] as String?;
      if (result['search_radius_km'] != null) {
        _searchRadiusKm = (result['search_radius_km'] as num).toDouble();
      }

      if (_requestId != null && mounted) {
        await _dispatchNextCandidate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = DispatchPhase.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _resumeExistingRequest() async {
    setState(() {
      _phase = DispatchPhase.searching;
      _errorMessage = null;
    });

    try {
      final req = await _supabaseService.getServiceRequest(_requestId!);
      if (req == null) {
        throw Exception('Service request not found.');
      }

      _requestCode = req['request_code'] as String?;
      if (req['search_radius_km'] != null) {
        _searchRadiusKm = (req['search_radius_km'] as num).toDouble();
      }

      final status = req['status'] as String?;
      if (status == 'assigned' ||
          status == 'en_route' ||
          status == 'arrived' ||
          status == 'diagnosing' ||
          status == 'quote_pending' ||
          status == 'servicing') {
        final mechanicId = req['mechanic_id'] as String?;
        if (mechanicId != null) {
          await _onMechanicAssigned(mechanicId);
          return;
        }
      }

      if (status == 'searching') {
        await _dispatchNextCandidate();
      } else if (status == 'cancelled' && mounted) {
        setState(() => _phase = DispatchPhase.cancelled);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = DispatchPhase.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _dispatchNextCandidate() async {
    if (_requestId == null) return;
    _stopTimers();

    if (mounted) {
      setState(() {
        _phase = DispatchPhase.searching;
      });
    }

    try {
      final result = await _supabaseService.dispatchNextCandidate(_requestId!);
      final status = result['status'] as String?;

      if (status == 'offered') {
        _candidateWorkshopName = result['workshop_name'] as String?;
        if (result['search_radius_km'] != null) {
          _searchRadiusKm = (result['search_radius_km'] as num).toDouble();
        }

        if (mounted) {
          setState(() {
            _phase = DispatchPhase.offered;
            _offerCountdown = 45;
          });
          _startOfferTimers();
        }
      } else if (status == 'exhausted') {
        final canExpand = result['can_expand'] as bool? ?? false;
        if (canExpand) {
          final newRadius =
              await _supabaseService.expandDispatchRadius(_requestId!);
          if (mounted) {
            setState(() => _searchRadiusKm = newRadius);
            await _dispatchNextCandidate();
          }
        } else {
          if (mounted) {
            setState(() => _phase = DispatchPhase.exhausted);
          }
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('already active')) {
        // Backend offer is still expiring (clock skew / network timing); wait and retry
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && (_phase == DispatchPhase.offered || _phase == DispatchPhase.searching)) {
          await _dispatchNextCandidate();
          return;
        }
      }
      if (mounted) {
        setState(() {
          _phase = DispatchPhase.error;
          _errorMessage = errStr.replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _startOfferTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_offerCountdown > 1) {
        if (mounted) {
          setState(() => _offerCountdown--);
        }
      } else {
        timer.cancel();
        // 1-second buffer ensures backend server clock has passed expiration before calling next candidate
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _phase == DispatchPhase.offered) {
            _dispatchNextCandidate();
          }
        });
      }
    });

    // Check request status every 2.5 seconds to detect mechanic acceptance
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (_requestId == null) return;
      final req = await _supabaseService.getServiceRequest(_requestId!);
      if (req != null) {
        final st = req['status'] as String?;
        if (st == 'assigned' ||
            st == 'en_route' ||
            st == 'arrived' ||
            st == 'diagnosing' ||
            st == 'quote_pending' ||
            st == 'servicing' ||
            st == 'completed') {
          _stopTimers();
          final mechanicId = req['mechanic_id'] as String?;
          if (mechanicId != null && mounted) {
            await _onMechanicAssigned(mechanicId, initialStatus: st);
          }
        }
      }
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onMechanicAssigned(String mechanicId, {String? initialStatus}) async {
    _stopTimers();
    _assignedMechanicId = mechanicId;
    _currentServiceStatus = initialStatus ?? 'assigned';
    final mechanic = await _supabaseService.getAssignedMechanic(mechanicId);
    if (mounted) {
      setState(() {
        _assignedMechanic = mechanic;
        _phase = DispatchPhase.assigned;
      });
      _startStatusMonitoring();
    }
  }

  void _startStatusMonitoring() {
    _statusSubscription?.cancel();
    _assignedPollTimer?.cancel();

    if (_requestId == null) return;

    // Realtime channel stream
    _statusSubscription = _supabaseService.streamServiceRequest(_requestId!).listen((list) async {
      if (!mounted || list.isEmpty) return;
      final req = list.first;
      final status = req['status'] as String?;
      if (status != null && status != _currentServiceStatus) {
        _handleStatusTransition(status);
      }
    });

    // Fallback polling every 3 seconds
    _assignedPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_requestId == null || !mounted) return;
      final req = await _supabaseService.getServiceRequest(_requestId!);
      if (req != null) {
        final status = req['status'] as String?;
        if (status != null && status != _currentServiceStatus) {
          _handleStatusTransition(status);
        }
      }
    });
  }

  Future<void> _handleStatusTransition(String newStatus) async {
    setState(() => _currentServiceStatus = newStatus);

    if (newStatus == 'quote_pending') {
      final quote = await _supabaseService.getQuotationForRequest(_requestId!);
      if (mounted && quote != null && quote['status'] == 'pending') {
        setState(() => _activeQuotation = quote);
        _showQuotationReviewSheet();
      }
    } else if (newStatus == 'completed' && !_paymentDone) {
      if (mounted) {
        _showPaymentSimulationSheet();
      }
    }
  }

  void _showQuotationReviewSheet() {
    if (_activeQuotation == null) return;
    final quoteId = _activeQuotation!['id'] as String;
    final diag = (_activeQuotation!['diagnostic_fee'] as num?)?.toDouble() ?? 0;
    final labor = (_activeQuotation!['labor_fee'] as num?)?.toDouble() ?? 0;
    final parts = (_activeQuotation!['parts_fee'] as num?)?.toDouble() ?? 0;
    final total = (_activeQuotation!['total_amount'] as num?)?.toDouble() ?? (diag + labor + parts);
    final lineItems = _activeQuotation!['line_items'] as Map<String, dynamic>? ?? {};
    final desc = lineItems['description'] as String? ?? 'Vehicle roadside repairs';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TECHNICIAN QUOTATION',
                  style: TextStyle(
                    color: AppColors.caliperCrimson,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('PENDING APPROVAL', style: TextStyle(color: AppColors.caliperCrimson, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              style: const TextStyle(color: AppColors.chassisText, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Diagnostic Inspection', '৳ ${diag.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            _buildInfoRow('Labor & Repair Fee', '৳ ${labor.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            _buildInfoRow('Replacement Parts', '৳ ${parts.toStringAsFixed(2)}'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Estimate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Text(
                  '৳ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.caliperCrimson, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _supabaseService.respondToQuotation(quotationId: quoteId, decision: 'rejected');
                      setState(() => _activeQuotation = null);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Quotation rejected.')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.caliperCrimson),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('REJECT', style: TextStyle(color: AppColors.caliperCrimson, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _supabaseService.respondToQuotation(quotationId: quoteId, decision: 'accepted');
                      setState(() {
                        _activeQuotation = null;
                        _currentServiceStatus = 'servicing';
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quotation approved! Technician has commenced work.'),
                            backgroundColor: AppColors.emeraldGps,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldGps,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('APPROVE & START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSimulationSheet() {
    String selectedMethod = 'bKash';
    double amount = 1000.0;
    if (_activeQuotation != null) {
      amount = (_activeQuotation!['total_amount'] as num?)?.toDouble() ?? 1000.0;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B82F6)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science, color: Color(0xFF3B82F6), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DEVELOPMENT PAYMENT SIMULATION (NO REAL MONEY CHARGED)',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Settle Rescue Bill',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Technician has completed your service. Confirm payment to record completion.',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '৳ ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.caliperCrimson,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Payment Method (Simulated):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['bKash', 'Nagad', 'Rocket', 'Cash'].map((method) {
                  final isSelected = selectedMethod == method;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(method, style: TextStyle(color: isSelected ? Colors.white : AppColors.chassisText, fontWeight: FontWeight.bold, fontSize: 11)),
                      selected: isSelected,
                      selectedColor: AppColors.caliperCrimson,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedMethod = method);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (_requestId != null) {
                      await _supabaseService.recordDevelopmentPayment(
                        requestId: _requestId!,
                        quotationId: _activeQuotation?['id'] ?? '00000000-0000-0000-0000-000000000000',
                        amount: amount,
                        paymentMethod: selectedMethod,
                      );
                    }
                    setState(() {
                      _paymentDone = true;
                      _currentServiceStatus = 'completed';
                    });
                    if (mounted) {
                      _showRatingDialog();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGps,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CONFIRM SIMULATED PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingDialog() {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rate Your Technician', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was the roadside repair and diagnostic response?', style: TextStyle(color: AppColors.slateMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    icon: Icon(
                      star <= selectedRating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = star),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Optional comment (e.g. fast arrival, great service)',
                  hintStyle: TextStyle(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                if (_requestId != null && _assignedMechanicId != null) {
                  try {
                    await _supabaseService.submitReview(
                      requestId: _requestId!,
                      mechanicId: _assignedMechanicId!,
                      rating: selectedRating,
                      comment: commentController.text,
                    );
                  } catch (_) {}
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Thank you! Review submitted successfully.'),
                    backgroundColor: AppColors.emeraldGps,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
              child: const Text('SUBMIT REVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSearch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Are you sure you want to cancel this emergency breakdown request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO, WAIT'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
            child: const Text('YES, CANCEL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _stopTimers();
      if (_requestId != null) {
        try {
          await _supabaseService.cancelServiceRequest(_requestId!);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _phase = DispatchPhase.cancelled);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // --------------------------------------------------------------------------
  // UI PRESENTATION
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.chassisText),
                    onPressed: () {
                      if (_phase == DispatchPhase.searching ||
                          _phase == DispatchPhase.offered) {
                        _cancelSearch();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  Text(
                    _phase == DispatchPhase.assigned
                        ? 'Rescue Active'
                        : (_phase == DispatchPhase.exhausted
                            ? 'Search Exhausted'
                            : 'Locating Mechanics'),
                    style: const TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isHighPriority
                          ? AppColors.crimsonLight
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.isHighPriority ? 'PRIORITY' : 'STANDBY',
                      style: TextStyle(
                        color: widget.isHighPriority
                            ? AppColors.caliperCrimson
                            : AppColors.slateMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Progress Indicator
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STEP 4 OF 4',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        _requestCode != null
                            ? 'REF: $_requestCode'
                            : 'DISPATCH & TELEMETRY',
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.caliperCrimson,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            // Main Body by Phase
            Expanded(
              child: _buildPhaseContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case DispatchPhase.submitting:
      case DispatchPhase.searching:
      case DispatchPhase.offered:
        return _buildSearchingView();
      case DispatchPhase.assigned:
        return _buildAssignedView();
      case DispatchPhase.exhausted:
        return _buildExhaustedView();
      case DispatchPhase.error:
        return _buildErrorView();
      case DispatchPhase.cancelled:
        return const Center(child: Text('Request cancelled.'));
    }
  }

  Widget _buildSearchingView() {
    final isOffered = _phase == DispatchPhase.offered;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _sonarController,
                  builder: (context, child) {
                    return Container(
                      width: 140 + (_sonarController.value * 60),
                      height: 140 + (_sonarController.value * 60),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.caliperCrimson
                              .withAlpha(((1.0 - _sonarController.value) * 255).round()),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.crimsonLight,
                    border: Border.all(color: AppColors.crimsonBorder),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.caliperCrimson,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, color: Colors.white, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              isOffered
                  ? 'Offer Dispatched to Technician'
                  : 'Broadcasting Breakdown Beacon',
              style: const TextStyle(
                color: AppColors.chassisText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOffered
                  ? 'Awaiting response from ${_candidateWorkshopName ?? 'nearby workshop'} ($_offerCountdown s remaining)...'
                  : 'Querying verified mobile workshops within ${_searchRadiusKm.toStringAsFixed(1)} km of ${widget.breakdownAddress}...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Vehicle: ${widget.vehicleType} • ${widget.licensePlate}',
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _cancelSearch,
              icon: const Icon(Icons.close, size: 16, color: AppColors.caliperCrimson),
              label: const Text('Cancel Search', style: TextStyle(color: AppColors.caliperCrimson)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.crimsonBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedView() {
    final workshopName = _assignedMechanic?['workshop_name'] ?? 'Assigned Workshop';
    final fullName = _assignedMechanic?['full_name'] ?? 'Roadside Specialist';
    final phone = _assignedMechanic?['phone'] ?? '+880 1700-000000';
    final rating = (_assignedMechanic?['rating'] as num?)?.toDouble() ?? 5.0;
    final totalRescues = _assignedMechanic?['total_rescues'] ?? 0;
    final workshopAddress = _assignedMechanic?['workshop_address'] ?? 'Dhaka';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assigned Technician Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1E293B),
                      child: Text(
                        fullName.length >= 2 ? fullName.substring(0, 2).toUpperCase() : 'RC',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: AppColors.emeraldGps, size: 14),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            workshopName,
                            style: const TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$workshopAddress • ${rating.toStringAsFixed(1)} ★ ($totalRescues rescues)',
                            style: const TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.slateBorder, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling $workshopName ($phone)...')),
                          );
                        },
                        icon: const Icon(Icons.phone, size: 16, color: Colors.white),
                        label: const Text('Call Mechanic', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldGps,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Mission Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _currentServiceStatus == 'completed'
                  ? AppColors.emeraldGps.withAlpha(20)
                  : (_currentServiceStatus == 'quote_pending'
                      ? AppColors.caliperCrimson.withAlpha(20)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentServiceStatus == 'completed'
                    ? AppColors.emeraldGps
                    : (_currentServiceStatus == 'quote_pending'
                        ? AppColors.caliperCrimson
                        : AppColors.slateBorder),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _currentServiceStatus == 'completed'
                      ? Icons.check_circle
                      : (_currentServiceStatus == 'quote_pending'
                          ? Icons.pending_actions
                          : Icons.autorenew),
                  color: _currentServiceStatus == 'completed'
                      ? AppColors.emeraldGps
                      : (_currentServiceStatus == 'quote_pending'
                          ? AppColors.caliperCrimson
                          : AppColors.slateMuted),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS: ${_currentServiceStatus.toUpperCase()}',
                        style: TextStyle(
                          color: _currentServiceStatus == 'completed'
                              ? AppColors.emeraldGps
                              : (_currentServiceStatus == 'quote_pending'
                                  ? AppColors.caliperCrimson
                                  : AppColors.chassisText),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        _getStatusDescription(_currentServiceStatus),
                        style: const TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contextual Action Banners
          if (_currentServiceStatus == 'quote_pending' && _activeQuotation != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.caliperCrimson),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Technician has submitted a repair quotation.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review line items and approve before technician begins work.',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _showQuotationReviewSheet,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
                      child: const Text('REVIEW & APPROVE QUOTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_currentServiceStatus == 'completed' && !_paymentDone) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emeraldGps),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service complete! Settle bill.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldGps),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Record test payment simulation (dev mode) and submit review.',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _showPaymentSimulationSheet,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
                      child: const Text('SETTLE BILL & RATE MECHANIC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Assigned Breakdown Service',
            style: TextStyle(color: AppColors.chassisText, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusDescription(_currentServiceStatus),
            style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Column(
              children: [
                _buildInfoRow('Request Code', _requestCode ?? 'RDX-PENDING'),
                const SizedBox(height: 8),
                _buildInfoRow('Fault Category', widget.selectedFault),
                const SizedBox(height: 8),
                _buildInfoRow('Vehicle', '${widget.vehicleType} (${widget.licensePlate})'),
                const SizedBox(height: 8),
                _buildInfoRow('Location', widget.breakdownAddress),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Return to Home Dashboard', style: TextStyle(color: AppColors.slateMuted)),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'assigned':
        return 'Technician has accepted your offer and is preparing to mobilize.';
      case 'en_route':
        return 'Technician is en route to your breakdown position.';
      case 'arrived':
        return 'Technician has arrived at the breakdown scene.';
      case 'diagnosing':
        return 'Technician is conducting diagnostic inspection of vehicle.';
      case 'quote_pending':
        return 'Technician has prepared a quotation requiring your approval.';
      case 'servicing':
        return 'Repair work is currently underway on your vehicle.';
      case 'completed':
        return 'Breakdown rescue completed successfully!';
      default:
        return 'Active roadside assistance operation.';
    }
  }

  Widget _buildExhaustedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off, color: AppColors.caliperCrimson, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Mechanics in 15 km Radius',
              style: TextStyle(color: AppColors.chassisText, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'We expanded the search to the maximum 15.0 km radius around ${widget.breakdownAddress}, but no verified on-duty mechanics are currently available.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling Police / Highway Emergency 999...')),
                  );
                },
                icon: const Icon(Icons.emergency, color: Colors.white),
                label: const Text('CALL EMERGENCY HELPLINE (999)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.caliperCrimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Return to Home', style: TextStyle(color: AppColors.slateMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.caliperCrimson, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Dispatch Request Error',
              style: TextStyle(color: AppColors.chassisText, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to communicate with the dispatch engine. Please check network connection.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestId != null ? _resumeExistingRequest : _createAndDispatch,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
              child: const Text('Retry Search', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back', style: TextStyle(color: AppColors.slateMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5)),
        Text(value, style: const TextStyle(color: AppColors.chassisText, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
