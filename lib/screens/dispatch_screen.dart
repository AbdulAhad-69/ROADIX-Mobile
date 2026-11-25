import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/geocoding_service.dart';
import '../services/sslcommerz_service.dart';
import '../services/supabase_service.dart';
import '../src/core/config/app_config.dart';
import '../src/core/utils/geometry_utils.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

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
  Timer? _totalDispatchTimer;
  int _totalSearchSecondsElapsed = 0;
  int _activeOfferRetries = 0;
  static const int maxTotalDispatchTimeoutSeconds = 180;
  bool _isDemoMode = false;
  bool _isAcceptingSimulation = false;
  List<LatLng>? _routeGeometry;
  double? _routeDistanceKm;
  int? _routeDurationMins;
  double? _lastRoutedMechLat;
  double? _lastRoutedMechLng;

  static final List<Map<String, dynamic>> _demoCandidates = [
    {
      'mechanic_id': 'demo-tech-01',
      'full_name': 'Md. Rafiqul Islam',
      'workshop_name': 'Uttara 24/7 Motors',
      'workshop_address': 'Sector 11, Uttara, Dhaka',
      'specialty': 'Engine & Electrical Specialist',
      'phone': '+8801811000011',
      'rating': 4.92,
      'total_rescues': 342,
      'distance_km': 2.4,
      'eta_mins': 9,
      'eta_label': '8-12m',
      'lat_offset': 0.006,
      'lng_offset': 0.005,
    },
    {
      'mechanic_id': 'demo-tech-02',
      'full_name': 'Al-Amin Heavy Rescue',
      'workshop_name': 'Al-Amin Heavy Rescue',
      'workshop_address': 'Airport Road, Kawla, Dhaka',
      'specialty': 'Heavy Recovery & Towing',
      'phone': '+8801711000022',
      'rating': 4.85,
      'total_rescues': 218,
      'distance_km': 4.1,
      'eta_mins': 16,
      'eta_label': '15-18m',
      'lat_offset': 0.012,
      'lng_offset': 0.009,
    },
  ];

  String? _assignedMechanicId;
  Map<String, dynamic>? _assignedMechanic;
  String? _candidateWorkshopName;
  String? _errorMessage;

  String _currentServiceStatus = 'searching';
  Map<String, dynamic>? _activeQuotation;
  bool _paymentDone = false;
  StreamSubscription? _statusSubscription;
  Timer? _assignedPollTimer;
  final List<Timer> _simulationTimers = [];

  MapLibreMapController? _assignedMapController;
  double? _mechanicLat;
  double? _mechanicLng;
  Timer? _mechanicTelemetryTimer;
  Line? _routeLine;
  Circle? _breakdownCircle;
  Circle? _mechanicCircle;

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
    _stopTimers();
    _assignedPollTimer?.cancel();
    _mechanicTelemetryTimer?.cancel();
    _statusSubscription?.cancel();
    _assignedMapController = null;
    super.dispose();
  }

  String get _formattedSearchLocation {
    final addr = widget.breakdownAddress.trim();
    final coordStr = '(${widget.breakdownLat.toStringAsFixed(4)}° N, ${widget.breakdownLng.toStringAsFixed(4)}° E)';
    if (addr.contains('•') || addr.startsWith('Roadside Position')) {
      final match = RegExp(r'^([A-Za-z\s]+ Region)\s*•').firstMatch(addr);
      final region = match?.group(1)?.trim();
      if (region != null && region.isNotEmpty) {
        return 'your roadside location in $region $coordStr';
      }
      return 'your roadside location $coordStr';
    }
    return addr;
  }

  // --------------------------------------------------------------------------
  // DISPATCH ENGINE INTEGRATION
  // --------------------------------------------------------------------------

  bool _isResumedInFlight = false;

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
          _isResumedInFlight = (existingStatus == 'searching');
          await _resumeExistingRequest();
          return;
        }
      }

      await _createNewDispatch();
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = DispatchPhase.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _createNewDispatch() async {
    try {
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
        _startTotalDispatchTimer();
        await _dispatchNextCandidate();
      }
    } catch (e) {
      if (!_supabaseService.isAuthenticated ||
          e.toString().contains('Authentication required')) {
        _startDemoRadarSimulation();
        return;
      }
      rethrow;
    }
  }

  void _startTotalDispatchTimer() {
    _totalDispatchTimer?.cancel();
    _totalSearchSecondsElapsed = 0;
    _totalDispatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _totalSearchSecondsElapsed++;
        });
      } else {
        _totalSearchSecondsElapsed++;
      }
      if (_totalSearchSecondsElapsed >= maxTotalDispatchTimeoutSeconds) {
        timer.cancel();
        _stopTimers();
        if (mounted &&
            (_phase == DispatchPhase.searching ||
                _phase == DispatchPhase.offered)) {
          setState(() {
            _phase = DispatchPhase.exhausted;
          });
        }
      }
    });
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Timer _scheduleSimulationTimer(Duration duration, void Function() callback) {
    late final Timer timer;
    timer = Timer(duration, () {
      _simulationTimers.remove(timer);
      if (mounted) {
        callback();
      }
    });
    _simulationTimers.add(timer);
    return timer;
  }

  void _startDemoRadarSimulation() {
    if (!mounted) return;
    _stopTimers();
    setState(() {
      _isDemoMode = true;
      _phase = DispatchPhase.searching;
      _requestCode = 'RDX-DEMO-8821';
      _searchRadiusKm = 5.0;
      _errorMessage = null;
      _isAcceptingSimulation = false;
    });

    _startTotalDispatchTimer();

    _scheduleSimulationTimer(const Duration(seconds: 2), () {
      if (mounted && _phase == DispatchPhase.searching && _isDemoMode) {
        setState(() => _searchRadiusKm = 10.0);
      }
    });

    _scheduleSimulationTimer(const Duration(seconds: 4), () {
      if (mounted && _phase == DispatchPhase.searching && _isDemoMode) {
        setState(() {
          _searchRadiusKm = 15.0;
          _candidateWorkshopName = 'Uttara 24/7 Motors';
          _phase = DispatchPhase.offered;
          _offerCountdown = 45;
        });

        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_offerCountdown > 1) {
            if (mounted) setState(() => _offerCountdown--);
          } else {
            _offerCountdown = 0;
            t.cancel();
            if (mounted && _phase == DispatchPhase.offered) {
              setState(() => _phase = DispatchPhase.exhausted);
            }
          }
        });

        // Demo simulation auto-advance fallback after 8 seconds (if user doesn't manually tap Accept):
        _scheduleSimulationTimer(const Duration(seconds: 8), () {
          if (mounted && _phase == DispatchPhase.offered && _isDemoMode && !_isAcceptingSimulation) {
            _simulateDemoMechanicAcceptance();
          }
        });
      }
    });
  }

  void _simulateDemoMechanicAcceptance([Map<String, dynamic>? selectedCandidate]) {
    if (_isAcceptingSimulation) return;
    _isAcceptingSimulation = true;
    _stopTimers();
    if (!mounted) return;

    final candidate = selectedCandidate ?? _demoCandidates.first;
    final latOffset = (candidate['lat_offset'] as num?)?.toDouble() ?? 0.006;
    final lngOffset = (candidate['lng_offset'] as num?)?.toDouble() ?? 0.005;

    setState(() {
      _phase = DispatchPhase.assigned;
      _currentServiceStatus = 'assigned';
      _assignedMechanicId = candidate['mechanic_id'] as String? ?? 'demo-technician-01';
      _assignedMechanic = {
        'full_name': candidate['full_name'],
        'workshop_name': candidate['workshop_name'],
        'workshop_address': candidate['workshop_address'],
        'specialty': candidate['specialty'],
        'phone': candidate['phone'],
        'rating': candidate['rating'],
        'total_rescues': candidate['total_rescues'],
        'mechanic_lat': widget.breakdownLat + latOffset,
        'mechanic_lng': widget.breakdownLng + lngOffset,
      };
      _mechanicLat = widget.breakdownLat + latOffset;
      _mechanicLng = widget.breakdownLng + lngOffset;
    });
    _syncMapVisuals();

    // Stage 4: En Route (4s)
    _scheduleSimulationTimer(const Duration(seconds: 4), () {
      if (mounted && _phase == DispatchPhase.assigned && _isDemoMode) {
        setState(() {
          _currentServiceStatus = 'en_route';
          _mechanicLat = widget.breakdownLat + (latOffset * 0.5);
          _mechanicLng = widget.breakdownLng + (lngOffset * 0.4);
        });
        _syncMapVisuals();
      }
    });

    // Stage 5: Arrived (8s)
    _scheduleSimulationTimer(const Duration(seconds: 8), () {
      if (mounted && _phase == DispatchPhase.assigned && _isDemoMode) {
        setState(() {
          _currentServiceStatus = 'arrived';
          _mechanicLat = widget.breakdownLat + 0.0005;
          _mechanicLng = widget.breakdownLng + 0.0004;
        });
        _syncMapVisuals();
      }
    });

    // Stage 6: Diagnosing (12s)
    _scheduleSimulationTimer(const Duration(seconds: 12), () {
      if (mounted && _phase == DispatchPhase.assigned && _isDemoMode) {
        setState(() {
          _currentServiceStatus = 'diagnosing';
        });
      }
    });

    // Stage 7: Quotation Submitted (16s)
    _scheduleSimulationTimer(const Duration(seconds: 16), () {
      if (mounted && _phase == DispatchPhase.assigned && _isDemoMode) {
        setState(() {
          _currentServiceStatus = 'quote_pending';
          _activeQuotation = {
            'id': 'demo-quote-${DateTime.now().millisecondsSinceEpoch}',
            'diagnostic_fee': 300.0,
            'labor_fee': 450.0,
            'parts_fee': 250.0,
            'total_amount': 1000.0,
            'status': 'pending',
            'line_items': {
              'description': '${widget.selectedFault} inspection, replacement parts & roadside labor'
            },
          };
        });
        _showQuotationReviewSheet();
      }
    });
  }

  Future<void> _cancelAndStartFresh() async {
    _stopTimers();
    if (_requestId != null) {
      try {
        await _supabaseService.cancelServiceRequest(
          _requestId!,
          reason: 'User cancelled prior search to start fresh dispatch',
        );
      } catch (_) {}
    }
    _requestId = null;
    _requestCode = null;
    _isResumedInFlight = false;
    _isDemoMode = false;
    _isAcceptingSimulation = false;
    await _createNewDispatch();
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
        _startTotalDispatchTimer();
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
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    if (mounted) {
      setState(() {
        _phase = DispatchPhase.searching;
      });
    }

    try {
      final result = await _supabaseService.dispatchNextCandidate(_requestId!);
      final status = result['status'] as String?;
      _activeOfferRetries = 0; // Reset counter on valid call

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
          _stopTimers();
          if (mounted) {
            setState(() => _phase = DispatchPhase.exhausted);
          }
          if (_requestId != null) {
            _supabaseService.cancelServiceRequest(
              _requestId!,
              reason: 'All mechanics within 15 km exhausted',
            ).catchError((_) {});
          }
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('already active')) {
        // Backend offer is still expiring; limit retries with progressive delay
        _activeOfferRetries++;
        if (_activeOfferRetries <= 3) {
          await Future.delayed(Duration(seconds: _activeOfferRetries * 2));
          if (mounted && (_phase == DispatchPhase.offered || _phase == DispatchPhase.searching)) {
            await _dispatchNextCandidate();
            return;
          }
        } else {
          // If already active persists beyond 3 attempts, avoid infinite recursion
          if (mounted) {
            setState(() => _phase = DispatchPhase.offered);
            _startOfferTimers();
            return;
          }
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
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_offerCountdown > 1) {
        if (mounted) {
          setState(() => _offerCountdown--);
        }
      } else {
        timer.cancel();
        // 1-second buffer ensures backend server clock has passed expiration before calling next candidate
        _scheduleSimulationTimer(const Duration(seconds: 1), () {
          if (mounted && _phase == DispatchPhase.offered) {
            _dispatchNextCandidate();
          }
        });
      }
    });

    // Check request status and offer status every 2.5 seconds to detect mechanic acceptance or decline
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
            return;
          }
        }
      }

      // Check if offer was declined/rejected by the mechanic
      if (_phase == DispatchPhase.offered) {
        final latestOffer = await _supabaseService.getLatestOfferForRequest(_requestId!);
        if (latestOffer != null) {
          final offerStatus = latestOffer['status'] as String?;
          if (offerStatus == 'rejected' || offerStatus == 'declined' || offerStatus == 'timed_out') {
            _countdownTimer?.cancel();
            _pollTimer?.cancel();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Technician unavailable. Searching next nearby workshop...'),
                  duration: Duration(seconds: 2),
                ),
              );
              await _dispatchNextCandidate();
            }
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
    _totalDispatchTimer?.cancel();
    _totalDispatchTimer = null;
    for (final timer in _simulationTimers) {
      timer.cancel();
    }
    _simulationTimers.clear();
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
        if (mechanic != null) {
          _mechanicLat = (mechanic['mechanic_lat'] as num?)?.toDouble() ??
              (mechanic['latitude'] as num?)?.toDouble();
          _mechanicLng = (mechanic['mechanic_lng'] as num?)?.toDouble() ??
              (mechanic['longitude'] as num?)?.toDouble();
        }
      });
      _startStatusMonitoring();
      _startTelemetryTracking();
      _syncMapVisuals();
    }
  }

  void _startTelemetryTracking() {
    _mechanicTelemetryTimer?.cancel();
    _mechanicTelemetryTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_assignedMechanicId == null || !mounted) return;
      final coords =
          await _supabaseService.getMechanicCoordinates(_assignedMechanicId!);
      if (coords != null && mounted) {
        setState(() {
          _mechanicLat = coords.$1;
          _mechanicLng = coords.$2;
        });
        _syncMapVisuals();
      }
    });
  }

  Future<void> _syncMapVisuals() async {
    final ctrl = _assignedMapController;
    if (ctrl == null) return;

    try {
      _breakdownCircle ??= await ctrl.addCircle(
        CircleOptions(
          geometry: LatLng(widget.breakdownLat, widget.breakdownLng),
          circleRadius: 8.0,
          circleColor: '#DC2626',
          circleStrokeWidth: 3.0,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      if (_mechanicLat != null && _mechanicLng != null) {
        final mechPos = LatLng(_mechanicLat!, _mechanicLng!);
        if (_mechanicCircle != null) {
          await ctrl.updateCircle(
            _mechanicCircle!,
            CircleOptions(geometry: mechPos),
          );
        } else {
          _mechanicCircle = await ctrl.addCircle(
            CircleOptions(
              geometry: mechPos,
              circleRadius: 8.0,
              circleColor: '#10B981',
              circleStrokeWidth: 3.0,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }

        final shouldFetchRoute = _routeGeometry == null ||
            _lastRoutedMechLat == null ||
            _lastRoutedMechLng == null ||
            (mechPos.latitude - _lastRoutedMechLat!).abs() > 0.001 ||
            (mechPos.longitude - _lastRoutedMechLng!).abs() > 0.001;

        if (shouldFetchRoute) {
          _lastRoutedMechLat = mechPos.latitude;
          _lastRoutedMechLng = mechPos.longitude;
          final routeResult = await GeocodingService.fetchDrivingRoute(
            fromLat: mechPos.latitude,
            fromLng: mechPos.longitude,
            toLat: widget.breakdownLat,
            toLng: widget.breakdownLng,
          );
          if (mounted) {
            setState(() {
              _routeGeometry = routeResult.points;
              _routeDistanceKm = routeResult.distanceKm;
              _routeDurationMins = routeResult.durationMinutes;
            });
          }
        }

        final routeGeom = _routeGeometry ??
            [mechPos, LatLng(widget.breakdownLat, widget.breakdownLng)];
        if (_routeLine != null) {
          await ctrl.updateLine(
            _routeLine!,
            LineOptions(geometry: routeGeom),
          );
        } else {
          _routeLine = await ctrl.addLine(
            LineOptions(
              geometry: routeGeom,
              lineColor: '#B91C1C',
              lineWidth: 4.5,
              lineOpacity: 0.9,
            ),
          );
        }
      }
    } catch (_) {
      // Map may be unmounting or style still re-binding
    }
  }

  void _startStatusMonitoring() {
    _statusSubscription?.cancel();
    _assignedPollTimer?.cancel();

    if (_requestId == null) return;

    // Realtime channel stream
    _statusSubscription = _supabaseService.streamServiceRequest(_requestId!).listen(
      (list) async {
        if (!mounted || list.isEmpty) return;
        final req = list.first;
        final status = req['status'] as String?;
        if (status != null && status != _currentServiceStatus) {
          _handleStatusTransition(status);
        }
      },
      onError: (e) {
        // Realtime stream error handled gracefully; fallback polling continues
      },
    );

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
        _showDigitalInvoiceAndPaymentSheet();
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
                      if (!_isDemoMode) {
                        await _supabaseService.respondToQuotation(
                          quotationId: quoteId,
                          decision: 'rejected',
                        );
                      }
                      if (!mounted) return;
                      setState(() {
                        _activeQuotation = null;
                        _currentServiceStatus = 'diagnosing';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Quotation rejected. Technician will revise the estimate.',
                          ),
                          backgroundColor: AppColors.crimsonHover,
                        ),
                      );
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
                      if (!_isDemoMode) {
                        try {
                          await _supabaseService.respondToQuotation(quotationId: quoteId, decision: 'accepted');
                        } catch (_) {}
                      }
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

                      // Stage 9: In simulation/demo mode, after quotation approval, schedule a 5-second servicing timer
                      // that automatically updates status to 'completed' and triggers _showDigitalInvoiceAndPaymentSheet()
                      if (_isDemoMode) {
                        _scheduleSimulationTimer(const Duration(seconds: 5), () {
                          if (mounted && _phase == DispatchPhase.assigned && _currentServiceStatus == 'servicing') {
                            setState(() {
                              _currentServiceStatus = 'completed';
                            });
                            _showDigitalInvoiceAndPaymentSheet();
                          }
                        });
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

  Future<void> _showDigitalInvoiceAndPaymentSheet() async {
    if (_activeQuotation == null && _requestId != null) {
      final q = await _supabaseService.getQuotationForRequest(_requestId!);
      if (mounted) setState(() => _activeQuotation = q);
    }

    final diag = (_activeQuotation?['diagnostic_fee'] as num?)?.toDouble() ?? 300.0;
    final labor = (_activeQuotation?['labor_fee'] as num?)?.toDouble() ?? 500.0;
    final parts = (_activeQuotation?['parts_fee'] as num?)?.toDouble() ?? 200.0;
    final total = (_activeQuotation?['total_amount'] as num?)?.toDouble() ?? (diag + labor + parts);
    final lineItems = _activeQuotation?['line_items'] as Map<String, dynamic>? ?? {};
    final desc = lineItems['description'] as String? ?? 'Vehicle roadside breakdown recovery';
    final quotationId = _activeQuotation?['id'] as String? ?? '00000000-0000-0000-0000-000000000000';
    final invoiceRef = 'INV-${_requestCode ?? 'RDX-SERVICE'}';

    String selectedMethod = 'SSLCommerz-bKash';
    bool isProcessing = false;

    if (!mounted) return;

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
              // Header Badge & Invoice Ref
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROADIX DIGITAL INVOICE',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        invoiceRef,
                        style: const TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedMethod.contains('bKash')) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.bkashPink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bkashCrimson.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BrandLogo(brand: 'bkash', size: 14),
                              SizedBox(width: 4),
                              Text(
                                'bKash MFS',
                                style: TextStyle(
                                  color: AppColors.bkashCrimson,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6)),
                        ),
                        child: const Text(
                          'SSLCOMMERZ SANDBOX',
                          style: TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Incident Context
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Vehicle', '${widget.vehicleType} (${widget.licensePlate})'),
                    const SizedBox(height: 4),
                    _buildInfoRow('Specialist', '${_assignedMechanic?['full_name'] ?? 'Technician'} • ${_assignedMechanic?['workshop_name'] ?? 'Workshop'}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Itemized Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.chassisText),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Callout & Diagnostic Fee', '৳ ${diag.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildInfoRow('Labor & Repair Service', '৳ ${labor.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildInfoRow('Parts & Consumables ($desc)', '৳ ${parts.toStringAsFixed(2)}'),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Settled Amount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(
                    '৳ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.caliperCrimson, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Select Payment Option:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'SSLCommerz-bKash',
                  'SSLCommerz-Nagad',
                  'SSLCommerz-Card',
                  'Cash Settlement',
                ].map((method) {
                  final isSelected = selectedMethod == method;
                  final displayLabel = method.replaceAll('SSLCommerz-', '');
                  Widget? iconWidget;
                  if (method.contains('bKash')) {
                    iconWidget = const BrandLogo(brand: 'bkash', size: 18);
                  } else if (method.contains('Nagad')) {
                    iconWidget = const BrandLogo(brand: 'nagad', size: 18);
                  } else if (method.contains('Card')) {
                    iconWidget = const Icon(Icons.credit_card, size: 18, color: Color(0xFF1E40AF));
                  } else {
                    iconWidget = const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669));
                  }

                  final isBkash = method.contains('bKash');
                  return ChoiceChip(
                    avatar: iconWidget,
                    label: Text(
                      displayLabel,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.chassisText,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: isBkash ? AppColors.bkashPink : AppColors.caliperCrimson,
                    backgroundColor: AppColors.cardWhite,
                    side: BorderSide(
                      color: isSelected
                          ? (isBkash ? AppColors.bkashCrimson : AppColors.caliperCrimson)
                          : AppColors.slateBorder,
                      width: 1.2,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedMethod = method);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setSheetState(() => isProcessing = true);
                          try {
                            final sslService = SSLCommerzService();
                            final sessionResult = await sslService.initiateSession(
                              requestId: _requestId ?? '',
                              amount: total,
                              customerName: _assignedMechanic?['motorist_name'] ?? 'Roadside Motorist',
                              customerPhone: '+8801700000000',
                            );

                            if (sessionResult.isSuccess && sessionResult.gatewayPageUrl != null) {
                              try {
                                final uri = Uri.parse(sessionResult.gatewayPageUrl!);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }

                            if (_requestId != null) {
                              await sslService.recordSettlement(
                                requestId: _requestId!,
                                quotationId: quotationId,
                                amount: total,
                                paymentMethod: selectedMethod,
                                gatewayTransactionId: sessionResult.transactionId,
                                additionalMetadata: {
                                  'invoice_ref': invoiceRef,
                                  'session_key': sessionResult.sessionKey ?? '',
                                  'is_simulated_fallback': sessionResult.isSimulatedFallback,
                                },
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted) {
                              setState(() {
                                _paymentDone = true;
                                _currentServiceStatus = 'completed';
                              });
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment settled via SSLCommerz Sandbox!'),
                                  backgroundColor: AppColors.emeraldGps,
                                ),
                              );
                              _showRatingDialog();
                            }
                          } catch (e) {
                            if (mounted) {
                              setSheetState(() => isProcessing = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Settlement error: $e'),
                                  backgroundColor: AppColors.caliperCrimson,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGps,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'SETTLE ৳ ${total.toStringAsFixed(2)} VIA SSLCOMMERZ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
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
    bool isSubmitting = false;

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
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Share feedback regarding the service...',
                  hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nav = Navigator.of(context);
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) {
                    nav.popUntil((route) => route.isFirst);
                  }
                });
              },
              child: const Text('LATER', style: TextStyle(color: AppColors.slateMuted)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(context);
                      setDialogState(() => isSubmitting = true);
                      if (_requestId != null && _assignedMechanicId != null && !_isDemoMode) {
                        try {
                          await _supabaseService.submitReview(
                            requestId: _requestId!,
                            mechanicId: _assignedMechanicId!,
                            rating: selectedRating,
                            comment: commentController.text.trim(),
                          );
                        } catch (_) {}
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Thank you! Your feedback has updated the technician trust score.'),
                            backgroundColor: AppColors.emeraldGps,
                          ),
                        );
                        Future.delayed(const Duration(milliseconds: 1200), () {
                          if (mounted) {
                            nav.popUntil((route) => route.isFirst);
                          }
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SUBMIT REVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  Flexible(
                    child: Text(
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                      Flexible(
                        child: Text(
                          _requestCode != null
                              ? 'REF: $_requestCode'
                              : 'DISPATCH & TELEMETRY',
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.slateBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 1.0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.caliperCrimson,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
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
        return _buildCancelledView();
    }
  }

  Widget _buildSearchingView() {
    final isOffered = _phase == DispatchPhase.offered;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // In-flight active request notice banner
            if (_isResumedInFlight) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Search Resumed (${_requestCode ?? 'RDX'})',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'An ongoing dispatch was found. You can resume or start fresh.',
                            style: TextStyle(color: Color(0xFFB45309), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _cancelAndStartFresh,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        backgroundColor: AppColors.caliperCrimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Start Fresh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Requirement 1: Active Visible Elapsed Search Timer Badge & Linear Progress Bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slateBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.crimsonLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.caliperCrimson,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Time: ${_formatDuration(_totalSearchSecondsElapsed)} / ${_formatDuration(maxTotalDispatchTimeoutSeconds)}',
                          style: const TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _totalSearchSecondsElapsed > 75
                              ? AppColors.crimsonLight
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(maxTotalDispatchTimeoutSeconds - _totalSearchSecondsElapsed).clamp(0, maxTotalDispatchTimeoutSeconds)}s left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _totalSearchSecondsElapsed > 75
                                ? AppColors.caliperCrimson
                                : AppColors.slateMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 220,
                      height: 5,
                      child: LinearProgressIndicator(
                        value: (_totalSearchSecondsElapsed / maxTotalDispatchTimeoutSeconds).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _totalSearchSecondsElapsed > 75
                              ? AppColors.caliperCrimson
                              : AppColors.emeraldGps,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!isOffered) ...[
              // Concentric Radar Canvas (5 km, 10 km, 15 km)
              _buildRadarCanvas(),
              const SizedBox(height: 24),
              const Text(
                'Broadcasting Breakdown Beacon',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Querying verified mobile workshops within ${_searchRadiusKm.toStringAsFixed(1)} km of $_formattedSearchLocation...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _buildVehicleBadge(),
              if (_isDemoMode) ...[
                const SizedBox(height: 16),
                _buildDemoShortcuts(),
              ],
            ] else ...[
              // Requirement 2: Candidate Offer Expiration Timer Badge & Progress Bar
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.caliperCrimson.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled, size: 16, color: AppColors.caliperCrimson),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_offerCountdown}s remaining • Expiring',
                            style: const TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        width: 200,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: (_offerCountdown / 45.0).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFFEE2E2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.caliperCrimson),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                'Mechanic Found • Candidate Queue',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Awaiting response from ${_candidateWorkshopName ?? 'nearby workshop'} • 2 verified workshops found near $_formattedSearchLocation',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 16),

              // Requirements 3 & 4: Candidate Queue & Prominent Manual Simulation Trigger
              for (int i = 0; i < _demoCandidates.length; i++)
                _buildCandidateCard(_demoCandidates[i], isPrimary: i == 0),

              const SizedBox(height: 6),
              _buildVehicleBadge(),
            ],

            const SizedBox(height: 24),
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

  Widget _buildRadarCanvas() {
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 15 km Outer Boundary Ring
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _searchRadiusKm >= 15.0
                    ? AppColors.caliperCrimson.withAlpha(90)
                    : AppColors.slateBorder,
                width: 1.5,
              ),
              color: _searchRadiusKm >= 15.0
                  ? AppColors.crimsonLight.withAlpha(30)
                  : Colors.transparent,
            ),
          ),
          const Positioned(
            top: 6,
            child: Text(
              '15 KM',
              style: TextStyle(
                color: AppColors.slateMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 10 km Intermediate Ring
          Container(
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _searchRadiusKm >= 10.0
                    ? AppColors.caliperCrimson.withAlpha(120)
                    : AppColors.slateBorder,
                width: 1.5,
              ),
              color: _searchRadiusKm >= 10.0
                  ? AppColors.crimsonLight.withAlpha(50)
                  : Colors.transparent,
            ),
          ),
          const Positioned(
            top: 40,
            child: Text(
              '10 KM',
              style: TextStyle(
                color: AppColors.slateMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 5 km Core Discrete Ring
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.caliperCrimson.withAlpha(160),
                width: 1.5,
              ),
              color: AppColors.crimsonLight.withAlpha(80),
            ),
          ),
          const Positioned(
            top: 72,
            child: Text(
              '5 KM',
              style: TextStyle(
                color: AppColors.slateMuted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Dynamic Animated Radar Pulse Sweeping Across Active Radius
          AnimatedBuilder(
            animation: _sonarController,
            builder: (context, child) {
              final double maxSpan = (_searchRadiusKm <= 5.0)
                  ? 110.0
                  : ((_searchRadiusKm <= 10.0) ? 175.0 : 240.0);
              final double currentSpan = 50.0 + (_sonarController.value * (maxSpan - 50.0));
              final double alphaVal = ((1.0 - _sonarController.value) * 220).clamp(0, 255);
              return Container(
                width: currentSpan,
                height: currentSpan,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.caliperCrimson.withAlpha(alphaVal.round()),
                    width: 2.0,
                  ),
                ),
              );
            },
          ),

          // Centerpiece: Roadside Telemetry Beacon & Radar Origin
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFEF4444),
                  AppColors.caliperCrimson,
                  Color(0xFF991B1B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.caliperCrimson.withAlpha(120),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.radar, color: Colors.white, size: 26),
          ),

          // Live Status Ping Dot
          Positioned(
            bottom: 92,
            right: 92,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.emeraldGps,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldGps.withAlpha(140),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleBadge() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VehicleIllustration(vehicleType: widget.vehicleType, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${widget.vehicleType} • ${widget.licensePlate}',
              style: const TextStyle(
                color: AppColors.chassisText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoShortcuts() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.touch_app, size: 16, color: AppColors.emeraldGps),
              SizedBox(width: 6),
              Text(
                'Demo Shortcuts:',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
              ),
            ],
          ),
          InkWell(
            onTap: () => _simulateDemoMechanicAcceptance(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emeraldGps,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              _stopTimers();
              setState(() => _phase = DispatchPhase.exhausted);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.caliperCrimson,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Timeout',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate, {required bool isPrimary}) {
    final fullName = candidate['full_name'] as String? ?? 'Specialist';
    final workshop = candidate['workshop_name'] as String? ?? 'Workshop';
    final specialty = candidate['specialty'] as String? ?? 'General Roadside';
    final rating = (candidate['rating'] as num?)?.toDouble() ?? 4.9;
    final rescues = candidate['total_rescues'] ?? 300;
    final distanceKm = (candidate['distance_km'] as num?)?.toDouble() ?? 2.5;
    final etaLabel = candidate['eta_label'] as String? ?? '8-12m';

    final displayName = fullName == workshop ? workshop : '$fullName - $workshop';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? AppColors.emeraldGps : AppColors.slateBorder,
          width: isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isPrimary ? 12 : 6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF1E293B),
                child: Text(
                  fullName.length >= 2 ? fullName.substring(0, 2).toUpperCase() : 'RC',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.emeraldGps, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        specialty,
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPrimary) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGps.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TOP MATCH',
                    style: TextStyle(
                      color: AppColors.emeraldGps,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Metrics Row: Rating, Rescues, Distance, ETA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${rating.toStringAsFixed(2)} ★',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.chassisText),
                    ),
                  ],
                ),
                Text(
                  '$rescues rescues',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slateMuted),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me, color: AppColors.slateMuted, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.chassisText),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car, color: AppColors.emeraldGps, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      'ETA: $etaLabel',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emeraldGps),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Prominent Trigger Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _simulateDemoMechanicAcceptance(candidate),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              label: Text(
                isPrimary ? 'Accept Offer (Simulate Mechanic)' : 'Select & Accept ($workshop)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary ? AppColors.emeraldGps : const Color(0xFF334155),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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

    double? distanceKm;
    if (_mechanicLat != null && _mechanicLng != null) {
      distanceKm = GeometryUtils.calculateDistanceKm(
        _mechanicLat!,
        _mechanicLng!,
        widget.breakdownLat,
        widget.breakdownLng,
      );
    }

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
                        onPressed: () async {
                          final targetPhone = phone.isNotEmpty
                              ? phone
                              : (_assignedMechanic?['phone'] as String? ?? '');
                          if (targetPhone.isNotEmpty) {
                            final ok = await PhoneUtils.launchCall(targetPhone);
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open phone dialer for $workshopName ($targetPhone).'),
                                  backgroundColor: AppColors.caliperCrimson,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mechanic phone number is unavailable.'),
                                backgroundColor: AppColors.caliperCrimson,
                              ),
                            );
                          }
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
          const SizedBox(height: 16),

          // Live Telemetry & Tracking Map Viewport
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slateBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (!WidgetsBinding.instance.runtimeType.toString().contains('Test'))
                  MapLibreMap(
                    styleString: AppConfig.mapStyleUrl,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.breakdownLat, widget.breakdownLng),
                      zoom: 14.0,
                    ),
                    compassEnabled: false,
                    onMapCreated: (ctrl) => _assignedMapController = ctrl,
                    onStyleLoadedCallback: _syncMapVisuals,
                  )
                else
                  Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Center(
                      child: Icon(Icons.map, color: AppColors.slateMuted, size: 36),
                    ),
                  ),
                // Dynamic Telemetry & ETA HUD
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite.withAlpha(240),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: AppColors.emeraldGps,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (_routeDistanceKm ?? distanceKm) != null
                                ? 'ETA: ~${_routeDurationMins ?? GeometryUtils.calculateEtaMinutes((_routeDistanceKm ?? distanceKm)!)} min • ${(_routeDistanceKm ?? distanceKm)!.toStringAsFixed(1)} km road'
                                : 'Awaiting technician GPS signal...',
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_mechanicLat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE GPS',
                              style: TextStyle(
                                color: AppColors.emeraldDark,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Recenter Camera Button
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_assigned_map',
                    backgroundColor: AppColors.cardWhite,
                    foregroundColor: AppColors.chassisText,
                    elevation: 2,
                    onPressed: () {
                      if (_assignedMapController != null) {
                        if (_mechanicLat != null && _mechanicLng != null) {
                          _assignedMapController!.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(_mechanicLat!, _mechanicLng!),
                            ),
                          );
                        } else {
                          _assignedMapController!.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(widget.breakdownLat, widget.breakdownLng),
                            ),
                          );
                        }
                      }
                    },
                    child: const Icon(Icons.my_location, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                    'Rescue Complete! Settle Digital Invoice',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldGps),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review official digital invoice and complete settlement via SSLCommerz Sandbox.',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _showDigitalInvoiceAndPaymentSheet,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
                      child: const Text('VIEW INVOICE & SETTLE (SSLCOMMERZ)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
              'We expanded the search to the maximum 15.0 km radius around $_formattedSearchLocation, but no verified on-duty mechanics are currently available.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await PhoneUtils.launchCall('999');
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open 999 dialer. Please dial 999 manually.'),
                        backgroundColor: AppColors.caliperCrimson,
                      ),
                    );
                  }
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
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _cancelAndStartFresh,
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.chassisText),
                label: const Text(
                  'CANCEL & START FRESH DISPATCH',
                  style: TextStyle(
                    color: AppColors.chassisText,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.slateBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Return to Home Dashboard', style: TextStyle(color: AppColors.slateMuted)),
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _startDemoRadarSimulation,
              icon: const Icon(Icons.play_arrow, size: 16, color: AppColors.chassisText),
              label: const Text(
                'Run Interactive Demo Simulation',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.slateBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppColors.cardWhite,
              ),
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

  Widget _buildCancelledView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.caliperCrimson.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.caliperCrimson.withAlpha(60),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.caliperCrimson,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Emergency Request Cancelled',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.chassisText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_requestCode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.porcelainBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Text(
                  'Code: $_requestCode',
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Your roadside assistance dispatch request has been safely cancelled. No workshops or technicians are dispatched to your coordinates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slateMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _cancelAndStartFresh,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  'START NEW EMERGENCY REQUEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.caliperCrimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined, size: 18, color: AppColors.chassisText),
                label: const Text(
                  'RETURN TO HOME DASHBOARD',
                  style: TextStyle(
                    color: AppColors.chassisText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.slateBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: AppColors.cardWhite,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => PhoneUtils.launchCall('999'),
              icon: const Icon(Icons.phone_in_talk, size: 14, color: AppColors.caliperCrimson),
              label: const Text(
                'Need immediate police/fire assistance? Call 999',
                style: TextStyle(
                  color: AppColors.caliperCrimson,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.chassisText, fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
