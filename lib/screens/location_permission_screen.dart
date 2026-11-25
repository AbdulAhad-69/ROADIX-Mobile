import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';
import 'location_confirm_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  final String selectedFault;

  const LocationPermissionScreen({super.key, required this.selectedFault});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoadingGps = false;

  Future<void> _requestAndGetLocation() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoadingGps = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled on your device. Please turn on GPS.'),
              backgroundColor: AppColors.caliperCrimson,
            ),
          );
        }
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission was denied.'),
                backgroundColor: AppColors.caliperCrimson,
              ),
            );
          }
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in app settings.'),
              backgroundColor: AppColors.caliperCrimson,
            ),
          );
        }
        setState(() => _isLoadingGps = false);
        return;
      }

      // Fetch live high-accuracy GPS position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationConfirmScreen(
              selectedFault: widget.selectedFault,
              initialLat: position.latitude,
              initialLng: position.longitude,
              accuracyMeters: position.accuracy.round(),
            ),
          ),
        );
      }
    } catch (e) {
      // Fallback gracefully if GPS times out
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS Signal delayed: Using standard Dhaka Sector. ($e)'),
            backgroundColor: AppColors.slateMuted,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationConfirmScreen(
              selectedFault: widget.selectedFault,
              initialLat: 23.8759,
              initialLng: 90.3795,
              accuracyMeters: 8,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const EmergencyHomeScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const Text(
                    'Your Location',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Step Progress: Step 1 of 4
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 1 OF 4',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'LOCATION TRIAGE',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
                        widthFactor: 0.25,
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

            // Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const Spacer(),

                    // GPS Radar Visual
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFEE2E2).withAlpha(100),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                        ),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                          ),
                        ),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.caliperCrimson,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.caliperCrimson.withAlpha(90),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Headings
                    const Text(
                      'Let’s find your location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Allow ROADIX to access your location so we can find verified mechanics near your breakdown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Informational Privacy Cards
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.near_me, color: AppColors.caliperCrimson, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Accurate assistance',
                                      style: TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Your location helps mechanics find your breakdown point.',
                                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Divider(color: AppColors.slateBorder, height: 1),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shield_outlined, color: Color(0xFF334155), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Location privacy',
                                      style: TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Your precise location is shared only as needed for your active assistance request.',
                                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Primary Action Button (Triggers Real Native GPS)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingGps ? null : _requestAndGetLocation,
                        icon: _isLoadingGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location, color: Colors.white, size: 18),
                        label: Text(
                          _isLoadingGps ? 'ACQUIRING GPS LOCK...' : 'USE MY CURRENT LOCATION',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.caliperCrimson,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Manual Option
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LocationConfirmScreen(
                              selectedFault: widget.selectedFault,
                              initialLat: 23.8759,
                              initialLng: 90.3795,
                              accuracyMeters: null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_location_alt_outlined, color: AppColors.slateMuted, size: 16),
                      label: const Text(
                        'Enter location manually',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}