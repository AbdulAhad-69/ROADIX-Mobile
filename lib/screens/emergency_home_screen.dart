import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'activity_screen.dart';
import 'dispatch_screen.dart';
import 'location_confirm_screen.dart';
import 'mechanic_home_screen.dart';
import 'profile_screen.dart';
import 'sos_screen.dart';
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
  bool _hasUnreadAlerts = true;
  Map<String, dynamic>? _activeRescueRequest;

  // Dynamic user & location telemetry
  String _userName = 'Motorist';
  String? _avatarUrl;
  bool _isNidVerified = false;
  String _currentLocationName = 'Dhaka Region';
  double _currentLat = 23.8759;
  double _currentLng = 90.3795;
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      final addr = await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentLocationName = addr;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentLocationName = 'Mirpur / Uttara Corridor, Dhaka';
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
        onFacilitySelected: (facilityName, lat, lng) {
          Navigator.pop(ctx);
          _startEmergencyTriage(facilityName, customLat: lat, customLng: lng);
        },
      ),
    );
  }

  void _openNotificationsSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationsBottomSheet(
        onMarkAllRead: () {
          setState(() => _hasUnreadAlerts = false);
        },
      ),
    );
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

  Future<void> _startEmergencyTriage(String faultName, {double? customLat, double? customLng}) async {
    HapticFeedback.lightImpact();
    final targetLat = customLat ?? _currentLat;
    final targetLng = customLng ?? _currentLng;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationConfirmScreen(
          selectedFault: faultName,
          initialLat: targetLat,
          initialLng: targetLng,
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
          isSelectingLocationOnly: true,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _currentLat = (result['lat'] as num?)?.toDouble() ?? _currentLat;
        _currentLng = (result['lng'] as num?)?.toDouble() ?? _currentLng;
        _currentLocationName = result['address'] as String? ?? _currentLocationName;
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
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.crimsonLight,
                                      backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                          ? (_avatarUrl!.startsWith('http')
                                              ? NetworkImage(_avatarUrl!)
                                              : AssetImage(_avatarUrl!) as ImageProvider)
                                          : null,
                                      onBackgroundImageError: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                          ? (e, s) {}
                                          : null,
                                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                          ? Text(
                                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                                              style: const TextStyle(
                                                color: AppColors.caliperCrimson,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                              ),
                                            )
                                          : null,
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
                                            color: AppColors.emeraldGps,
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

                    // Top Right: Technician Console Mode Switch, Notifications & Search
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Technician Console Mode Switcher Pill
                          Flexible(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MechanicHomeScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.engineering_outlined, color: Colors.white, size: 12),
                                      SizedBox(width: 3),
                                      Text(
                                        'Tech Console',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),

                        // Notification Bell
                        InkWell(
                          onTap: _openNotificationsSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.chassisText,
                                  size: 20,
                                ),
                                if (_hasUnreadAlerts)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 7,
                                      height: 7,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),

                        // Search Icon
                        InkWell(
                          onTap: _openSearchSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(
                              Icons.search,
                              color: AppColors.chassisText,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
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

            // Modern 3-Tab Bottom Navigation Bar
            Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: const Border(top: BorderSide(color: AppColors.slateBorder)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Home (ROADIX Emblem)
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeNavIndex = 0);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          color: _activeNavIndex == 0
                              ? AppColors.caliperCrimson
                              : AppColors.slateMuted,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.alt_route,
                            size: 22,
                            color: _activeNavIndex == 0
                                ? AppColors.caliperCrimson
                                : AppColors.slateMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _activeNavIndex == 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _activeNavIndex == 0
                                ? AppColors.caliperCrimson
                                : AppColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 1: Activity
                  _buildBottomNavItem(Icons.history, 'Activity', 1),

                  // Tab 2: Profile
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

          // Dynamic Location Indicator Card
          InkWell(
            onTap: _openLocationConfirm,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slateBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.caliperCrimson.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: AppColors.caliperCrimson.withAlpha(35),
                              width: 1.0,
                            ),
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
                              Row(
                                children: const [
                                  Flexible(
                                    child: Text(
                                      'DETECTED LOCATION',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  CircleAvatar(
                                    radius: 3.5,
                                    backgroundColor: AppColors.emeraldGps,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isLoadingLocation ? 'Locating vehicle...' : _currentLocationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: const [
                      Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
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

          const SizedBox(height: 14),

          // Primary Header Copy
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
            'Dispatch certified mechanics with specialized tools across Dhaka within minutes.',
            style: TextStyle(
              color: AppColors.slateMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),

          const Spacer(),

          // Dominant Centerpiece: Multi-Ring Breathing SOS Trigger with Dual-Ring Radial Glow
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost Atmospheric Aura Ring
                      Container(
                        width: 204,
                        height: 204,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.caliperCrimson.withAlpha(45),
                            width: 1.5,
                          ),
                          gradient: RadialGradient(
                            colors: [
                              AppColors.caliperCrimson.withAlpha(0),
                              AppColors.caliperCrimson.withAlpha(30),
                            ],
                          ),
                        ),
                      ),
                      // Middle Tactical Pulse Ring with Accent Dash Border
                      Container(
                        width: 172,
                        height: 172,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF87171).withAlpha(160),
                            width: 2,
                          ),
                          color: AppColors.crimsonLight.withAlpha(140),
                        ),
                      ),
                      // Inner Glow Foundation with Dual Drop Shadow
                      Container(
                        width: 144,
                        height: 144,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.caliperCrimson.withAlpha(140),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      // Core High-Impact Action Button
                      InkWell(
                        onTap: _showSosConfirmationModal,
                        borderRadius: BorderRadius.circular(68),
                        child: Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.25, -0.35),
                              radius: 0.95,
                              colors: [
                                Color(0xFFFF5252),
                                AppColors.caliperCrimson,
                                Color(0xFF881337),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha(80),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'PRESS FOR HELP',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ROADSIDE EMERGENCY DISPATCH',
                  style: TextStyle(
                    color: AppColors.caliperCrimson,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap button to choose breakdown service',
                  style: TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Defect Categories Header & Clean Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Flexible(
                child: Text(
                  'What do you need help with?',
                  style: TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Instant triage',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2-Row Responsive Breakdown Cards Layout with Elevated Modern Styling
          Column(
            children: [
              Row(
                children: [
                  _buildCategoryCard(
                    title: 'Battery',
                    badge: 'Jump / 12V',
                    icon: Icons.battery_charging_full,
                    accentColor: const Color(0xFFD97706),
                    fullFault: 'Dead Battery',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Flat Tire',
                    badge: 'Puncture',
                    icon: Icons.album_outlined,
                    accentColor: AppColors.caliperCrimson,
                    fullFault: 'Flat Tire',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Engine',
                    badge: 'Thermal',
                    icon: Icons.warning_amber_rounded,
                    accentColor: const Color(0xFFEA580C),
                    fullFault: 'Engine Trouble',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCategoryCard(
                    title: 'Fuel',
                    badge: '5L Delivery',
                    icon: Icons.local_gas_station_outlined,
                    accentColor: const Color(0xFF0284C7),
                    fullFault: 'Out of Fuel',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    title: 'Towing',
                    badge: 'Flatbed',
                    icon: Icons.local_shipping_outlined,
                    accentColor: const Color(0xFF4F46E5),
                    fullFault: 'Towing',
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
    required String badge,
    required IconData icon,
    required Color accentColor,
    required String fullFault,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _startEmergencyTriage(fullFault);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slateBorder),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
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
