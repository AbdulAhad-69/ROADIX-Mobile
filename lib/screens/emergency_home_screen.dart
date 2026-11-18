import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'activity_screen.dart';
import 'dispatch_screen.dart';
import 'location_permission_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkActiveRescue();
  }

  Future<void> _checkActiveRescue() async {
    try {
      final active = await SupabaseService().getActiveServiceRequest();
      if (mounted && active != null) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SearchBottomSheet(
        onFacilitySelected: (facilityName, lat, lng) {
          _startEmergencyTriage(facilityName);
        },
      ),
    );
  }

  void _openNotificationsSheet() {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.porcelainBg,
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
              'Select Emergency Type',
              style: TextStyle(
                color: AppColors.chassisText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose the service required for your current situation',
              style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 20),

            // Card 1: 999 Police/Medical Panic Dialer
            InkWell(
              onTap: () {
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
                            'Immediate life-threatening accidents & security',
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

  Future<void> _startEmergencyTriage(String faultName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationPermissionScreen(selectedFault: faultName),
      ),
    );
    if (mounted) {
      _checkActiveRescue();
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
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Left: User Photo & Name
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                          child: const Center(
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.crimsonLight,
                              child: Icon(
                                Icons.person,
                                color: AppColors.caliperCrimson,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sheikh Abdul Ahad',
                              style: TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Top Right: Notifications & Search
                    Row(
                      children: [
                        // Notification Bell
                        InkWell(
                          onTap: _openNotificationsSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.chassisText,
                                  size: 22,
                                ),
                                if (_hasUnreadAlerts)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: AppColors.caliperCrimson,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.porcelainBg,
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Search Icon
                        InkWell(
                          onTap: _openSearchSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: const Icon(
                              Icons.search,
                              color: AppColors.chassisText,
                              size: 22,
                            ),
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
                  const ActivityScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),

            // 3-Tab Bottom Navigation Bar (Logo as Home icon)
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(top: BorderSide(color: AppColors.slateBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Home (ROADIX Emblem)
                  InkWell(
                    onTap: () => setState(() => _activeNavIndex = 0),
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
                            size: 20,
                            color: _activeNavIndex == 0
                                ? AppColors.caliperCrimson
                                : AppColors.slateMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _activeNavIndex == 0
                                ? FontWeight.w800
                                : FontWeight.w500,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          if (_activeRescueRequest != null) ...[
            InkWell(
              onTap: () async {
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
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.crimsonLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.caliperCrimson),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar,
                        color: AppColors.caliperCrimson, size: 20),
                    const SizedBox(width: 10),
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
                          Text(
                            'Status: ${_activeRescueRequest!['status']} • Ref: ${_activeRescueRequest!['request_code'] ?? 'RDX'}',
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

          // Location Indicator Card
          InkWell(
            onTap: () => _startEmergencyTriage('General Breakdown'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.caliperCrimson,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR LOCATION',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: const [
                              Text(
                                'Mirpur, Dhaka',
                                style: TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              CircleAvatar(
                                radius: 3.5,
                                backgroundColor: AppColors.emeraldGps,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.slateMuted,
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
          const SizedBox(height: 4),
          const Text(
            'Get connected with a verified mechanic near you, when you need help most.',
            style: TextStyle(
              color: AppColors.slateMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const Spacer(),

          // Dominant Centerpiece: Breathing SOS Trigger
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
                          border: Border.all(color: AppColors.crimsonBorder),
                          color: AppColors.crimsonLight.withAlpha(70),
                        ),
                      ),
                      Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF87171).withAlpha(100),
                            width: 2,
                          ),
                          color: AppColors.crimsonLight.withAlpha(150),
                        ),
                      ),
                      InkWell(
                        onTap: _showSosConfirmationModal,
                        borderRadius: BorderRadius.circular(65),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.caliperCrimson,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.caliperCrimson.withAlpha(110),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'PRESS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
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
                  'GET ROADSIDE HELP',
                  style: TextStyle(
                    color: AppColors.caliperCrimson,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap to choose emergency type',
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

          // Dhaka Coverage Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: Color(0xFF475569),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Roadside assistance across Dhaka',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Availability depends on nearby verified mechanics.',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Defect Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'What do you need help with?',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Select to begin triage',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildCategoryCard('Dead Battery', Icons.battery_charging_full),
              const SizedBox(width: 6),
              _buildCategoryCard('Flat Tire', Icons.album_outlined),
              const SizedBox(width: 6),
              _buildCategoryCard('Engine Trouble', Icons.warning_amber_rounded),
              const SizedBox(width: 6),
              _buildCategoryCard(
                'Out of Fuel',
                Icons.local_gas_station_outlined,
              ),
              const SizedBox(width: 6),
              _buildCategoryCard('Towing', Icons.local_shipping_outlined),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: () => _startEmergencyTriage(title),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.slateBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.porcelainBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: AppColors.caliperCrimson, size: 16),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
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
      onTap: () => setState(() => _activeNavIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? AppColors.caliperCrimson : AppColors.slateMuted,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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