import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import '../services/supabase_service.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/contact_editor_sheet.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  bool _isCancelled = false;

  String _currentAddress = 'Detecting roadside position...';
  double _currentLat = 23.8759;
  double _currentLng = 90.3795;
  int? _accuracyMeters;
  bool _hasGpsFix = false;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();

    // Pulse animation for radar ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 5-second countdown controller running at 60 fps
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _countdownController.reverse(from: 1.0);

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_isCancelled) {
        _triggerEmergencyCall();
      }
    });

    _detectLocation();
    _loadEmergencyContacts();
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      if (!serviceEnabled) {
        _handleLocationFallback();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _handleLocationFallback();
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (pos != null && mounted) {
        final lat = pos.latitude;
        final lng = pos.longitude;
        final acc = pos.accuracy.round();
        final addr = await GeocodingService.reverseGeocode(lat, lng);
        if (mounted) {
          setState(() {
            _hasGpsFix = true;
            _currentLat = lat;
            _currentLng = lng;
            _accuracyMeters = acc;
            _currentAddress = addr;
          });
        }
      } else {
        _handleLocationFallback();
      }
    } catch (_) {
      _handleLocationFallback();
    }
  }

  void _handleLocationFallback() {
    if (mounted) {
      final division = GeocodingService.detectDivision(_currentLat, _currentLng);
      final region = division.isNotEmpty ? '$division Region' : 'Regional';
      setState(() {
        _hasGpsFix = false;
        _accuracyMeters = null;
        _currentAddress = '$region Highway Corridor (Estimated)';
      });
    }
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final contacts = await _db.getEmergencyContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  Future<void> _triggerEmergencyCall() async {
    HapticFeedback.heavyImpact();
    final success = await PhoneUtils.launchCall('999');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🚨 999 Emergency Dispatch Initiated!'
                : '🚨 Could not open dialer automatically. Please dial 999.',
          ),
          backgroundColor: AppColors.caliperCrimson,
        ),
      );
    }
  }

  void _cancelSos() {
    HapticFeedback.mediumImpact();
    _countdownController.stop();
    setState(() => _isCancelled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency call cancelled.'),
        backgroundColor: AppColors.chassisText,
      ),
    );
  }

  void _openAddContactSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactEditorSheet(
        onSave: (savedData) async {
          await _db.addEmergencyContact(
            name: savedData['name']!,
            phone: savedData['phone']!,
            relation: savedData['relation']!,
          );
          _loadEmergencyContacts();
        },
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
            // Top Bar with Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Emergency Mode',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.chassisText, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // High-Visibility Emergency Red Alert Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.caliperCrimson,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'EMERGENCY SOS ACTIVE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subtitle & Status
            const SizedBox(height: 12),
            const Text(
              'EMERGENCY 999 DISPATCH',
              style: TextStyle(
                color: AppColors.chassisText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.circle, color: AppColors.caliperCrimson, size: 7),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Alerting Highway Police & Contacts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Centerpiece: Fluid 5-Second Circular Dial
            AnimatedBuilder(
              animation: _countdownController,
              builder: (context, child) {
                final int remainingSeconds = (_countdownController.value * 5).ceil().clamp(0, 5);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Glow
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.caliperCrimson.withAlpha(90),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        // Progress Ring
                        SizedBox(
                          width: 118,
                          height: 118,
                          child: CircularProgressIndicator(
                            value: _isCancelled ? 0.0 : _countdownController.value,
                            strokeWidth: 5.0,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.caliperCrimson),
                            backgroundColor: AppColors.slateBorder,
                          ),
                        ),

                        // 999 Dial Button
                        InkWell(
                          onTap: _triggerEmergencyCall,
                          borderRadius: BorderRadius.circular(46),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.caliperCrimson,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.caliperCrimson.withAlpha(120),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '999',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isCancelled
                                      ? 'CANCELLED'
                                      : (remainingSeconds > 0 ? 'CALLING (${remainingSeconds}s)' : 'CONNECTED'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tap to Cancel Pill Button
                    if (!_isCancelled)
                      InkWell(
                        onTap: _cancelSos,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.slateBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.chassisText.withAlpha(6),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'TAP TO CANCEL (${remainingSeconds}s)',
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            const Spacer(),

            // Dispatch Quick Action Cards (Highway Patrol & Ambulance)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  _buildEmergencyServiceCard(
                    icon: Icons.shield_outlined,
                    title: 'CALL HIGHWAY PATROL',
                    subtitle: 'Toll-Free • 24/7 Response (999)',
                    accentColor: const Color(0xFF2563EB),
                    badgeText: 'POLICE 999',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final ok = await PhoneUtils.launchCall('999');
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open dialer for Highway Patrol.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildEmergencyServiceCard(
                    icon: Icons.local_hospital_outlined,
                    title: 'CALL AMBULANCE',
                    subtitle: 'Critical Medical Response (999)',
                    accentColor: AppColors.caliperCrimson,
                    badgeText: 'MEDICAL 999',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final ok = await PhoneUtils.launchCall('999');
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open dialer for Ambulance.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live Dynamic GPS Coordinates Card with Precision Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slateBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.chassisText.withAlpha(5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.caliperCrimson.withAlpha(40),
                        ),
                      ),
                      child: const Icon(Icons.location_on, color: AppColors.caliperCrimson, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currentLat.toStringAsFixed(4)}° N, ${_currentLng.toStringAsFixed(4)}° E',
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _hasGpsFix ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _hasGpsFix ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _hasGpsFix && _accuracyMeters != null
                            ? '±${_accuracyMeters}m Acc'
                            : 'GPS Estimating',
                        style: TextStyle(
                          color: _hasGpsFix ? const Color(0xFF059669) : const Color(0xFFD97706),
                          fontSize: 9.0,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Emergency Contacts Broadcast Row (Real contacts from Supabase)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.circle, color: AppColors.emeraldGps, size: 6),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'EMERGENCY CONTACTS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_contacts.length} Configured ✓',
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingContacts)
                    const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.caliperCrimson)))
                  else if (_contacts.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _contacts.map((c) {
                          final name = c['name']?.toString() ?? 'Contact';
                          final phone = c['phone']?.toString() ?? '';
                          final relation = c['relation']?.toString() ?? 'Family';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildContactPill(name, relation, const Color(0xFF9F1239), () {
                              if (phone.isNotEmpty) {
                                PhoneUtils.launchCall(phone);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    )
                  else
                    InkWell(
                      onTap: _openAddContactSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.slateBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add, size: 14, color: AppColors.caliperCrimson),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '+ Add Emergency Contact to alert automatically',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.caliperCrimson, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  ),
),
),
    );
  }

  Widget _buildEmergencyServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color accentColor = AppColors.caliperCrimson,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withAlpha(60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withAlpha(14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: accentColor.withAlpha(40),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
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
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 9.0,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone, color: accentColor, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPill(String name, String relation, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slateBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: color.withAlpha(30),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  relation,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.call, size: 12, color: AppColors.caliperCrimson),
          ],
        ),
      ),
    );
  }
}
