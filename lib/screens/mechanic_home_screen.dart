import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';

class MechanicHomeScreen extends StatefulWidget {
  const MechanicHomeScreen({super.key});

  @override
  State<MechanicHomeScreen> createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = true;
  String _profileId = '';
  Map<String, dynamic>? _mechanicProfile;
  bool _isOnDuty = false;
  bool _isVerified = false;
  List<String> _vehicleSpecializations = [];

  // Active Offer & Service Request
  Map<String, dynamic>? _activeOffer;
  int _offerCountdown = 45;
  Timer? _offerTimer;
  Timer? _refreshTimer;

  Map<String, dynamic>? _activeRescue;
  StreamSubscription? _offerSub;
  StreamSubscription? _requestSub;

  static const List<String> _canonicalCategories = [
    'Passenger Car',
    'Motorcycle',
    'Light Commercial',
  ];

  @override
  void initState() {
    super.initState();
    _initMechanicState();
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _refreshTimer?.cancel();
    _offerSub?.cancel();
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> _initMechanicState() async {
    setState(() => _isLoading = true);
    try {
      _profileId = _db.currentProfileId;
      final profile = await _db.ensureMechanicProfile();
      if (mounted) {
        setState(() {
          _mechanicProfile = profile;
          _isVerified = profile['is_verified'] as bool? ?? false;
          _isOnDuty = profile['is_on_duty'] as bool? ?? false;
          _vehicleSpecializations = List<String>.from(
            profile['vehicle_specializations'] ?? ['Passenger Car', 'Motorcycle'],
          );
          _isLoading = false;
        });
      }

      await _pollForOffersAndRescues();
      _setupRealtime();

      // Periodic check every 4 seconds as a reliable fallback
      _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) _pollForOffersAndRescues();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize mechanic console: $e'),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    }
  }

  void _setupRealtime() {
    _offerSub?.cancel();
    _offerSub = _db.streamIncomingOffers(_profileId).listen((offers) {
      if (!mounted) return;
      final active = offers.where((o) => o['status'] == 'offered').toList();
      if (active.isNotEmpty) {
        _setIncomingOffer(active.first);
      } else if (_activeOffer != null) {
        setState(() => _activeOffer = null);
        _offerTimer?.cancel();
      }
    });
  }

  Future<void> _pollForOffersAndRescues() async {
    try {
      // 1. Check for incoming offers
      final offers = await _db.getIncomingOffers();
      if (offers.isNotEmpty && _activeRescue == null) {
        _setIncomingOffer(offers.first);
      } else if (offers.isEmpty && _activeOffer != null) {
        if (mounted) {
          setState(() => _activeOffer = null);
          _offerTimer?.cancel();
        }
      }

      // 2. Check for active assigned rescue
      final activeReq = await _db.getActiveMechanicRescue(_profileId);

      if (mounted) {
        setState(() {
          _activeRescue = activeReq;
        });
      }
    } catch (_) {}
  }

  void _setIncomingOffer(Map<String, dynamic> offer) {
    if (_activeOffer?['id'] == offer['id']) return;

    final expiresAtStr = offer['expires_at'] as String?;
    int remaining = 45;
    if (expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr)?.toUtc();
      if (expiresAt != null) {
        remaining = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      }
    }

    if (remaining <= 0) return;

    setState(() {
      _activeOffer = offer;
      _offerCountdown = remaining;
    });

    _offerTimer?.cancel();
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_offerCountdown > 1) {
        if (mounted) setState(() => _offerCountdown--);
      } else {
        timer.cancel();
        if (mounted) {
          setState(() => _activeOffer = null);
          _pollForOffersAndRescues();
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // ACTIONS
  // --------------------------------------------------------------------------

  Future<void> _toggleDuty(bool value) async {
    // Non-negotiable product rule: Unverified mechanics cannot go on duty.
    if (value && !_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification pending. An administrator must approve your workshop in Web Admin before you can go on duty.'),
          backgroundColor: AppColors.caliperCrimson,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isOnDuty = value);
    try {
      await _db.updateMechanicDuty(value);
      if (value) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          await _db.updateMechanicLocation(lat: pos.latitude, lng: pos.longitude);
        } catch (_) {
          // Fallback to roadside coordinates if device GPS permission pending
          await _db.updateMechanicLocation(lat: 23.8103, lng: 90.4125);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'You are now ON DUTY (Receiving Dispatches)' : 'You are now OFF DUTY'),
          backgroundColor: value ? AppColors.emeraldGps : AppColors.slateMuted,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOnDuty = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _toggleSpecialization(String category) async {
    final updated = List<String>.from(_vehicleSpecializations);
    if (updated.contains(category)) {
      if (updated.length == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one vehicle category is required.')),
        );
        return;
      }
      updated.remove(category);
    } else {
      updated.add(category);
    }

    setState(() => _vehicleSpecializations = updated);
    try {
      await _db.updateMechanicSpecializations(vehicleSpecializations: updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle Specializations updated: ${updated.join(', ')}'),
          backgroundColor: AppColors.emeraldGps,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _acceptOffer() async {
    if (_activeOffer == null) return;
    final offerId = _activeOffer!['id'] as String;
    final requestId = _activeOffer!['request_id'] as String;

    try {
      final success = await _db.acceptDispatchOffer(
        requestId: requestId,
        offerId: offerId,
      );
      _offerTimer?.cancel();
      if (!mounted) return;
      setState(() => _activeOffer = null);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispatch Offer Accepted! Mobilizing to scene.'),
            backgroundColor: AppColors.emeraldGps,
          ),
        );
        await _pollForOffersAndRescues();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer expired or was assigned to another workshop.'),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting offer: $e')),
      );
    }
  }

  Future<void> _rejectOffer() async {
    if (_activeOffer == null) return;
    final offerId = _activeOffer!['id'] as String;

    try {
      await _db.rejectDispatchOffer(offerId);
      _offerTimer?.cancel();
      if (!mounted) return;
      setState(() => _activeOffer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining offer: $e')),
      );
    }
  }

  Future<void> _advanceRescueStatus(String nextStatus) async {
    if (_activeRescue == null) return;
    final requestId = _activeRescue!['id'] as String;

    try {
      await _db.updateServiceStatus(requestId: requestId, status: nextStatus);
      await _pollForOffersAndRescues();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to: ${nextStatus.toUpperCase()}'),
          backgroundColor: AppColors.emeraldGps,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to advance status: $e')),
      );
    }
  }

  void _openQuotationBuilder() {
    if (_activeRescue == null) return;
    final requestId = _activeRescue!['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuotationBuilderSheet(
        requestId: requestId,
        onQuotationSent: () {
          Navigator.pop(ctx);
          _pollForOffersAndRescues();
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI PRESENTATION
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.porcelainBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.caliperCrimson),
        ),
      );
    }

    final workshopName = _mechanicProfile?['workshop_name'] ?? 'ROADIX Partner Workshop';
    final workshopAddress = _mechanicProfile?['workshop_address'] ?? 'Dhaka';
    final rating = (_mechanicProfile?['rating'] as num?)?.toDouble() ?? 5.0;
    final totalRescues = _mechanicProfile?['total_rescues'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TECHNICIAN CONSOLE',
              style: TextStyle(
                color: AppColors.caliperCrimson,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              workshopName,
              style: const TextStyle(
                color: AppColors.chassisText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
              );
            },
            icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.slateMuted),
            label: const Text(
              'Motorist Mode',
              style: TextStyle(color: AppColors.slateMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop Status Card
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isOnDuty
                                  ? AppColors.emeraldGps.withAlpha(25)
                                  : AppColors.slateBorder.withAlpha(50),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isOnDuty ? Icons.build_circle : Icons.nightlight_round,
                              color: _isOnDuty ? AppColors.emeraldGps : AppColors.slateMuted,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                                    style: TextStyle(
                                      color: _isOnDuty ? AppColors.emeraldGps : AppColors.slateMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: AppColors.emeraldGps, size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                workshopAddress,
                                style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isOnDuty,
                        onChanged: _toggleDuty,
                        activeThumbColor: AppColors.emeraldGps,
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.slateBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricCol('Rating', '${rating.toStringAsFixed(1)} ★'),
                      _buildMetricCol('Completed', '$totalRescues Rescues'),
                      _buildMetricCol('Status', _isOnDuty ? 'Available' : 'Paused'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Vehicle Specializations Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.directions_car, color: AppColors.caliperCrimson, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Vehicle Specializations',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select vehicle classes you are equipped to service. Scoring formula prioritizes matching workshops.',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _canonicalCategories.map((cat) {
                      final isSelected = _vehicleSpecializations.contains(cat);
                      return FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.chassisText,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _toggleSpecialization(cat),
                        backgroundColor: const Color(0xFFF1F5F9),
                        selectedColor: AppColors.caliperCrimson,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Active Incoming Offer Alert
            if (_activeOffer != null) ...[
              _buildIncomingOfferCard(),
              const SizedBox(height: 20),
            ],

            // Active Rescue Operations
            if (_activeRescue != null) ...[
              _buildActiveRescueCard(),
              const SizedBox(height: 20),
            ],

            if (_activeOffer == null && _activeRescue == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isOnDuty ? Icons.radar : Icons.power_settings_new,
                      color: _isOnDuty ? AppColors.emeraldGps : AppColors.slateMuted,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isOnDuty ? 'Listening for Roadside Dispatches' : 'Turn On Duty to Receive Calls',
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isOnDuty
                          ? 'When a motorist within 15 km requests assistance for your vehicle specializations, an alert will ring here.'
                          : 'Toggle the switch above to mark your mobile workshop available on the live map.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingOfferCard() {
    final offer = _activeOffer!;
    final req = offer['service_requests'] as Map<String, dynamic>? ?? {};
    final requestCode = req['request_code'] ?? 'RDX-ALERT';
    final fault = req['fault_type'] ?? 'Emergency Breakdown';
    final address = req['breakdown_address'] ?? 'Dhaka Position';
    final vehicle = req['vehicle_snapshot'] as Map<String, dynamic>? ?? {};
    final vehicleType = vehicle['vehicle_type'] ?? 'Vehicle';
    final plate = vehicle['plate'] ?? 'TBD';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.caliperCrimson, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.caliperCrimson,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'INCOMING DISPATCH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer, color: AppColors.caliperCrimson, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_offerCountdown s',
                    style: const TextStyle(
                      color: AppColors.caliperCrimson,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fault,
            style: const TextStyle(
              color: AppColors.chassisText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ref: $requestCode • $vehicleType ($plate)',
            style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place, color: AppColors.slateMuted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(color: AppColors.chassisText, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectOffer,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.caliperCrimson),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('DECLINE', style: TextStyle(color: AppColors.caliperCrimson, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGps,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ACCEPT OFFER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRescueCard() {
    final rescue = _activeRescue!;
    final requestCode = rescue['request_code'] ?? 'RDX-ACTIVE';
    final status = (rescue['status'] as String?) ?? 'assigned';
    final address = rescue['breakdown_address'] ?? 'Dhaka';
    final fault = rescue['fault_type'] ?? 'Breakdown';
    final vehicle = rescue['vehicle_snapshot'] as Map<String, dynamic>? ?? {};
    final vehicleType = vehicle['vehicle_type'] ?? 'Vehicle';
    final plate = vehicle['plate'] ?? 'TBD';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emeraldGps, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGps,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE RESCUE MISSION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$fault ($requestCode)',
            style: const TextStyle(
              color: AppColors.chassisText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vehicle: $vehicleType • Plate: $plate',
            style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Location: $address',
            style: const TextStyle(color: AppColors.chassisText, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Contextual State Progression Button
          _buildProgressionAction(status),
        ],
      ),
    );
  }

  Widget _buildProgressionAction(String status) {
    switch (status) {
      case 'assigned':
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _advanceRescueStatus('en_route'),
            icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
            label: const Text('START EN ROUTE TO SCENE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
          ),
        );
      case 'en_route':
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _advanceRescueStatus('arrived'),
            icon: const Icon(Icons.place, color: Colors.white, size: 18),
            label: const Text('MARK ARRIVED ON SCENE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
          ),
        );
      case 'arrived':
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _advanceRescueStatus('diagnosing'),
            icon: const Icon(Icons.search, color: Colors.white, size: 18),
            label: const Text('BEGIN DIAGNOSIS & INSPECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
          ),
        );
      case 'diagnosing':
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _openQuotationBuilder,
            icon: const Icon(Icons.request_quote, color: Colors.white, size: 18),
            label: const Text('CREATE & SEND QUOTATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.caliperCrimson),
          ),
        );
      case 'quote_pending':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.caliperCrimson),
              ),
              SizedBox(width: 10),
              Text(
                'Quotation Sent — Awaiting Motorist Approval',
                style: TextStyle(color: AppColors.chassisText, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case 'servicing':
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _advanceRescueStatus('completed'),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label: const Text('FINISH SERVICE & COMPLETE RESCUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGps),
          ),
        );
      case 'completed':
        return const Center(
          child: Text(
            'Rescue Completed! Motorist will complete payment.',
            style: TextStyle(color: AppColors.emeraldGps, fontWeight: FontWeight.bold),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.chassisText, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 10)),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// QUOTATION BUILDER BOTTOM SHEET
// ----------------------------------------------------------------------------

class _QuotationBuilderSheet extends StatefulWidget {
  final String requestId;
  final VoidCallback onQuotationSent;

  const _QuotationBuilderSheet({
    required this.requestId,
    required this.onQuotationSent,
  });

  @override
  State<_QuotationBuilderSheet> createState() => _QuotationBuilderSheetState();
}

class _QuotationBuilderSheetState extends State<_QuotationBuilderSheet> {
  final _diagController = TextEditingController(text: '300');
  final _laborController = TextEditingController(text: '500');
  final _partsController = TextEditingController(text: '200');
  final _itemDescController = TextEditingController(text: 'Brake Fluid / Fuse');

  bool _isSubmitting = false;

  double get _totalAmount {
    final d = double.tryParse(_diagController.text) ?? 0;
    final l = double.tryParse(_laborController.text) ?? 0;
    final p = double.tryParse(_partsController.text) ?? 0;
    return d + l + p;
  }

  @override
  void dispose() {
    _diagController.dispose();
    _laborController.dispose();
    _partsController.dispose();
    _itemDescController.dispose();
    super.dispose();
  }

  Future<void> _submitQuote() async {
    setState(() => _isSubmitting = true);
    try {
      final diag = double.tryParse(_diagController.text) ?? 0;
      final labor = double.tryParse(_laborController.text) ?? 0;
      final parts = double.tryParse(_partsController.text) ?? 0;

      await SupabaseService().submitQuotation(
        requestId: widget.requestId,
        diagnosticFee: diag,
        laborFee: labor,
        partsFee: parts,
        lineItems: {
          'description': _itemDescController.text,
          'parts_bdt': parts,
          'labor_bdt': labor,
          'diagnostic_bdt': diag,
        },
      );

      widget.onQuotationSent();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send quote: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CREATE SERVICE QUOTATION',
                  style: TextStyle(
                    color: AppColors.caliperCrimson,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField('Diagnostic Inspection Fee (BDT)', _diagController),
            const SizedBox(height: 10),
            _buildField('Labor & Repair Fee (BDT)', _laborController),
            const SizedBox(height: 10),
            _buildField('Replacement Parts Cost (BDT)', _partsController),
            const SizedBox(height: 10),
            _buildField('Parts Description & Notes', _itemDescController, isNumber: false),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable (BDT):', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '৳ ${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.caliperCrimson,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.caliperCrimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SEND QUOTATION TO MOTORIST',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isNumber = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.slateBorder),
            ),
          ),
        ),
      ],
    );
  }
}
