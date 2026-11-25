import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import '../services/notifications_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'activity_screen.dart';
import 'dispatch_screen.dart';
import 'location_confirm_screen.dart';
import 'location_permission_screen.dart';
import 'profile_screen.dart';
import 'sos_screen.dart';
import '../widgets/roadix_avatar.dart';
import '../widgets/roadix_pressable.dart';
import '../widgets/search_bottom_sheet.dart';
import '../widgets/notifications_bottom_sheet.dart';

class EmergencyHomeScreen extends StatefulWidget {
  const EmergencyHomeScreen({super.key});

  @override
  State<EmergencyHomeScreen> createState() => _EmergencyHomeScreenState();
}

class _EmergencyHomeScreenState extends State<EmergencyHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  int _activeNavIndex = 0;
  bool _hasUnreadAlerts = false;
  Map<String, dynamic>? _activeRescueRequest;

  // Dynamic user & location telemetry
  String _userName = 'Motorist';
  String? _avatarUrl;
  bool _isNidVerified = false;
  String _currentLocationName = 'Dhaka Region';
  double _currentLat = 23.8759;
  double _currentLng = 90.3795;
  int? _currentAccuracyMeters;
  bool _hasLiveGpsLock = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkActiveRescue();
    _loadUserProfile();
    _detectCurrentLocation();
    _refreshUnreadAlerts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await SupabaseService().getProfile();
      if (mounted && profile != null) {
        setState(() {
          _userName = profile['full_name'] as String? ?? 'Motorist';
          _avatarUrl = profile['avatar_url'] as String?;
          _isNidVerified = profile['is_nid_verified'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _detectCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _hasLiveGpsLock = false;
            _currentAccuracyMeters = null;
            _currentLocationName = 'Dhaka Sector (Tap Change to Pin)';
            _isLoadingLocation = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      final addr =
          await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentAccuracyMeters = pos.accuracy.round();
          _hasLiveGpsLock = true;
          _currentLocationName = addr;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLiveGpsLock = false;
          _currentAccuracyMeters = null;
          _currentLocationName = 'Uttara / Dhaka Corridor (Estimated)';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _checkActiveRescue() async {
    try {
      final active = await SupabaseService().getActiveServiceRequest();
      if (mounted) {
        setState(() => _activeRescueRequest = active);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openSearchSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SearchBottomSheet(
        currentLat: _currentLat,
        currentLng: _currentLng,
        onFacilitySelected: (facilityName, lat, lng) {
          // SearchBottomSheet already pops itself before invoking this callback.
          setState(() {
            _currentLat = lat;
            _currentLng = lng;
            _currentLocationName = facilityName;
            _hasLiveGpsLock = false;
            _currentAccuracyMeters = null;
          });
          _startEmergencyTriage(
            'General Breakdown',
            customLat: lat,
            customLng: lng,
            accuracyMeters: null,
          );
        },
      ),
    );
  }

  Future<void> _openNotificationsSheet() async {
    HapticFeedback.lightImpact();
    final stillUnread = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsBottomSheet(),
    );
    if (stillUnread != null && mounted) {
      setState(() => _hasUnreadAlerts = stillUnread);
    } else if (mounted) {
      _refreshUnreadAlerts();
    }
  }

  Future<void> _refreshUnreadAlerts() async {
    final unread = await NotificationsService.hasUnreadNotifications();
    if (mounted) setState(() => _hasUnreadAlerts = unread);
  }

  void _showSosConfirmationModal() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Emergency Action',
              style: TextStyle(
                color: AppColors.chassisText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Immediate roadside assistance or direct 999 panic dialer',
              style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 20),

            // Card 1: 999 Police/Medical Panic Dialer
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SosScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.crimsonLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.crimsonBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.caliperCrimson,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Call 999 Police / Medical',
                            style: TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Life-threatening emergencies, crime, highway security',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.caliperCrimson,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card 2: Roadside Breakdown Assistance Wizard
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
                _startEmergencyTriage('General Breakdown');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slateBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.chassisText.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        color: AppColors.chassisText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Request Breakdown Mechanic',
                            style: TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Battery, tire puncture, towing, engine, fuel repair',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.slateMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startEmergencyTriage(
    String faultName, {
    double? customLat,
    double? customLng,
    int? accuracyMeters,
  }) async {
    HapticFeedback.lightImpact();

    if (customLat == null && customLng == null && !_hasLiveGpsLock) {
      bool serviceEnabled = false;
      LocationPermission permission = LocationPermission.denied;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        permission = await Geolocator.checkPermission();
      } catch (_) {}

      if (!mounted) return;
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationPermissionScreen(selectedFault: faultName),
          ),
        );
        if (mounted) _checkActiveRescue();
        return;
      }
    }

    final targetLat = customLat ?? _currentLat;
    final targetLng = customLng ?? _currentLng;
    final effAccuracy =
        customLat != null ? accuracyMeters : _currentAccuracyMeters;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationConfirmScreen(
          selectedFault: faultName,
          initialLat: targetLat,
          initialLng: targetLng,
          accuracyMeters: effAccuracy,
        ),
      ),
    );
    if (mounted) {
      _checkActiveRescue();
    }
  }

  Future<void> _openLocationConfirm() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LocationConfirmScreen(
          selectedFault: 'General Breakdown',
          initialLat: _currentLat,
          initialLng: _currentLng,
          accuracyMeters: _currentAccuracyMeters,
          isSelectingLocationOnly: true,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _currentLat = (result['lat'] as num?)?.toDouble() ?? _currentLat;
        _currentLng = (result['lng'] as num?)?.toDouble() ?? _currentLng;
        _currentLocationName =
            result['address'] as String? ?? _currentLocationName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: User Profile & Actions Header (Active on Home tab)
            if (_activeNavIndex == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Left: User Photo & Name (Tapping jumps to Profile tab)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeNavIndex = 2);
                          _loadUserProfile();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.cardWhite,
                                    border: Border.all(
                                      color: AppColors.slateBorder,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.chassisText.withAlpha(8),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: RoadixAvatar(
                                      displayName: _userName,
                                      avatarUrl: _avatarUrl,
                                      radius: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Welcome,',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.slateMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            height: 1.1,
                                          ),
                                        ),
                                        if (_isNidVerified) ...[
                                          const SizedBox(width: 3),
                                          const Icon(
                                            Icons.verified,
                                            color: AppColors.emeraldDark,
                                            size: 12,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Top Right: Notifications & Search (48dp accessible touch targets)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: _openNotificationsSheet,
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.chassisText,
                                size: 22,
                              ),
                            ),
                            if (_hasUnreadAlerts)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.caliperCrimson,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.porcelainBg,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Search nearby services',
                          onPressed: _openSearchSheet,
                          icon: const Icon(
                            Icons.search,
                            color: AppColors.chassisText,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Tab Body (IndexedStack switching between Home, Activity, and Profile)
            Expanded(
              child: IndexedStack(
                index: _activeNavIndex,
                children: [
                  _buildHomeContent(),
                  const ActivityScreen(showBackButton: false),
                  const ProfileScreen(showBackButton: false),
                ],
              ),
            ),

            // Clean 3-Tab Bottom Navigation Bar
            Container(
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(top: BorderSide(color: AppColors.slateBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomNavItem(Icons.home_outlined, 'Home', 0),
                  _buildBottomNavItem(Icons.history, 'Activity', 1),
                  _buildBottomNavItem(Icons.person_outline, 'Profile', 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const SizedBox(height: 4),

          // Active Rescue Banner (Real-time in-flight recovery)
          if (_activeRescueRequest != null) ...[
            InkWell(
              onTap: () async {
                HapticFeedback.selectionClick();
                final snapshot = _activeRescueRequest!['vehicle_snapshot']
                    as Map<String, dynamic>?;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DispatchScreen(
                      selectedFault: _activeRescueRequest!['fault_type']
                              as String? ??
                          'General Breakdown',
                      vehicleType: snapshot?['vehicle_type'] as String? ??
                          'Passenger Car',
                      licensePlate: snapshot?['plate'] as String? ?? '',
                      symptoms: const [],
                      isHighPriority:
                          _activeRescueRequest!['is_high_priority'] == true,
                      existingRequestId: _activeRescueRequest!['id'] as String?,
                    ),
                  ),
                );
                if (mounted) {
                  _checkActiveRescue();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.crimsonLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.caliperCrimson, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.caliperCrimson.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.caliperCrimson,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.radar, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACTIVE RESCUE IN PROGRESS',
                            style: TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Status: ${_activeRescueRequest!['status']?.toString().toUpperCase()} • Ref: ${_activeRescueRequest!['request_code'] ?? 'RDX'}',
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: AppColors.caliperCrimson, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Clean Dynamic Location Indicator Bar
          RoadixPressable(
            onTap: _openLocationConfirm,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.crimsonLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.caliperCrimson,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLoadingLocation ? 'Locating vehicle...' : _currentLocationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 3.5,
                                    backgroundColor: _hasLiveGpsLock
                                        ? AppColors.emeraldDark
                                        : AppColors.amberDark,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _hasLiveGpsLock && _currentAccuracyMeters != null
                                        ? 'GPS Locked (±${_currentAccuracyMeters}m)'
                                        : 'Tap Change to pin exact spot',
                                    style: const TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.caliperCrimson,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Stranded on the road?',
            style: TextStyle(
              color: AppColors.chassisText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Dispatch certified mechanics with specialized tools across Bangladesh within minutes.',
            style: TextStyle(
              color: AppColors.slateMuted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),

          const Spacer(),

          // Clean Architectural SOS Trigger (57efb64 heritage)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.crimsonBorder,
                            width: 1.5,
                          ),
                          color: AppColors.crimsonLight.withAlpha(90),
                        ),
                      ),
                      RoadixPressable(
                        onTap: _showSosConfirmationModal,
                        borderRadius: BorderRadius.circular(72),
                        child: Semantics(
                          button: true,
                          label: 'Trigger Emergency SOS options',
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.caliperCrimson,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'TAP FOR HELP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Get Roadside Help',
                  style: TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap SOS for dispatch or Highway 999 emergency',
                  style: TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Balanced Breakdown Category Grid
          const Text(
            'What do you need help with?',
            style: TextStyle(
              color: AppColors.chassisText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),

          Column(
            children: [
              Row(
                children: [
                  _buildCategoryCard(
                    title: 'Battery',
                    icon: Icons.battery_charging_full,
                    fullFault: 'Dead Battery',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Flat Tire',
                    icon: Icons.album_outlined,
                    fullFault: 'Flat Tire',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Engine',
                    icon: Icons.warning_amber_rounded,
                    fullFault: 'Engine Trouble',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCategoryCard(
                    title: 'Out of Fuel',
                    icon: Icons.local_gas_station_outlined,
                    fullFault: 'Out of Fuel',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Towing',
                    icon: Icons.local_shipping_outlined,
                    fullFault: 'Towing',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Other Issue',
                    icon: Icons.build_outlined,
                    fullFault: 'General Breakdown',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required String fullFault,
  }) {
    return Expanded(
      child: RoadixPressable(
        onTap: () {
          HapticFeedback.lightImpact();
          _startEmergencyTriage(fullFault);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slateBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.porcelainBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.caliperCrimson, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _activeNavIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeNavIndex = index);
        if (index == 0) {
          _checkActiveRescue();
          _loadUserProfile();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? AppColors.caliperCrimson : AppColors.slateMuted,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? AppColors.caliperCrimson
                  : AppColors.slateMuted,
            ),
          ),
        ],
      ),
    );
  }
}
