import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../services/geocoding_service.dart';
import '../src/core/config/app_config.dart';
import '../theme/app_colors.dart';
import 'vehicle_select_screen.dart';

class LocationConfirmScreen extends StatefulWidget {
  final String selectedFault;
  final double initialLat;
  final double initialLng;
  final int accuracyMeters;
  final bool isSelectingLocationOnly;

  const LocationConfirmScreen({
    super.key,
    required this.selectedFault,
    this.initialLat = 23.8759,
    this.initialLng = 90.3795,
    this.accuracyMeters = 8,
    this.isSelectingLocationOnly = false,
  });

  @override
  State<LocationConfirmScreen> createState() => _LocationConfirmScreenState();
}

class _LocationConfirmScreenState extends State<LocationConfirmScreen> {
  MapLibreMapController? _mapController;
  late LatLng _currentCenter;
  String get _styleUrl => AppConfig.mapStyleUrl;
  String _currentAddress = 'Dhaka Region • Roadside Position';
  bool _isGeocoding = false;
  bool _isLocating = false;
  late int _currentAccuracy;

  @override
  void initState() {
    super.initState();
    _currentAccuracy = widget.accuracyMeters;
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    _fetchAddress(_currentCenter.latitude, _currentCenter.longitude);
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    setState(() => _isGeocoding = true);
    final addr = await GeocodingService.reverseGeocode(lat, lng);
    if (mounted) {
      setState(() {
        _currentAddress = addr;
        _isGeocoding = false;
      });
    }
  }

  Future<void> _recenterToCurrentLocation() async {
    HapticFeedback.lightImpact();
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled on your device. Please turn on GPS.'),
              backgroundColor: AppColors.caliperCrimson,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _fallbackToInitial();
        return;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      } catch (_) {}

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Showing preset location.'),
              backgroundColor: AppColors.caliperCrimson,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _fallbackToInitial();
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
        final target = LatLng(pos.latitude, pos.longitude);
        final acc = pos.accuracy.round();
        setState(() {
          _currentCenter = target;
          _currentAccuracy = acc;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(target));
        _fetchAddress(pos.latitude, pos.longitude);
      } else {
        _fallbackToInitial();
      }
    } catch (_) {
      _fallbackToInitial();
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _fallbackToInitial() {
    final target = LatLng(widget.initialLat, widget.initialLng);
    if (mounted) {
      setState(() {
        _currentCenter = target;
        _currentAccuracy = widget.accuracyMeters;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(target));
      _fetchAddress(target.latitude, target.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.chassisText,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Flexible(
                    child: Text(
                      'Confirm Location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: AppColors.emeraldGps,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'GPS LOCK',
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Step Indicator: Step 1 of 4
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 2.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.isSelectingLocationOnly ? 'LOCATION PICKER' : 'STEP 1 OF 4',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.caliperCrimson,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.isSelectingLocationOnly ? 'CUSTOM POSITION' : 'LOCATION TRIAGE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
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

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Where is your vehicle?',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pinpoint your breakdown location so your mechanic knows exactly where to find you.',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Center Interactive Map Canvas
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vector Map
                  MapLibreMap(
                    styleString: _styleUrl,
                    initialCameraPosition: CameraPosition(
                      target: _currentCenter,
                      zoom: 15.5,
                    ),
                    compassEnabled: false,
                    onMapCreated: (ctrl) => _mapController = ctrl,
                    onCameraIdle: () {
                      if (_mapController != null) {
                        final pos = _mapController!.cameraPosition?.target;
                        if (pos != null) {
                          setState(() => _currentCenter = pos);
                          _fetchAddress(pos.latitude, pos.longitude);
                        }
                      }
                    },
                  ),

                  // Fixed Center Target Pin
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.chassisText,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(90),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircleAvatar(
                              radius: 3,
                              backgroundColor: AppColors.caliperCrimson,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'BREAKDOWN POSITION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.location_on,
                        color: AppColors.caliperCrimson,
                        size: 40,
                      ),
                    ],
                  ),

                  // Recenter Button
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: InkWell(
                      onTap: _recenterToCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slateBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: _isLocating
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.caliperCrimson,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: AppColors.caliperCrimson,
                                size: 20,
                              ),
                      ),
                    ),
                  ),

                  // OpenStreetMap & Geoapify Required Attribution
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite.withAlpha(220),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors • © Geoapify',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Confirmed Location Details Panel
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(top: BorderSide(color: AppColors.slateBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Flexible(
                        child: Text(
                          'BREAKDOWN LOCATION',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Drag map or tap preset',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickZoneChip('Airport Rd', 23.8512, 90.4078),
                        _buildQuickZoneChip('Uttara Sec 7', 23.8732, 90.3980),
                        _buildQuickZoneChip('Kuril Flyover', 23.8190, 90.4200),
                        _buildQuickZoneChip('Mirpur 10', 23.8069, 90.3687),
                        _buildQuickZoneChip('Gulshan 2', 23.7925, 90.4078),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.crimsonLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pin_drop,
                          color: AppColors.caliperCrimson,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_currentCenter.latitude.toStringAsFixed(4)}° N, ${_currentCenter.longitude.toStringAsFixed(4)}° E',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFA7F3D0),
                                    ),
                                  ),
                                  child: Text(
                                    _isGeocoding ? 'resolving...' : '± ${_currentAccuracy}m accuracy',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Primary Action CTA
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        if (widget.isSelectingLocationOnly) {
                          Navigator.of(context).pop({
                            'lat': _currentCenter.latitude,
                            'lng': _currentCenter.longitude,
                            'address': _currentAddress,
                          });
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VehicleSelectScreen(
                              selectedFault: widget.selectedFault,
                              breakdownLat: _currentCenter.latitude,
                              breakdownLng: _currentCenter.longitude,
                              breakdownAddress: _currentAddress,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caliperCrimson,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.isSelectingLocationOnly ? 'CONFIRM LOCATION' : 'CONFIRM LOCATION',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              widget.isSelectingLocationOnly ? Icons.check : Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      widget.isSelectingLocationOnly
                          ? 'Set your current location for emergency assistance'
                          : 'Step 1 of 4 • Next: Vehicle Classification',
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickZoneChip(String label, double lat, double lng) {
    final bool isSelected = (_currentCenter.latitude - lat).abs() < 0.001 &&
        (_currentCenter.longitude - lng).abs() < 0.001;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          final target = LatLng(lat, lng);
          setState(() => _currentCenter = target);
          _mapController?.animateCamera(CameraUpdate.newLatLng(target));
          _fetchAddress(lat, lng);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimsonLight : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.caliperCrimson : AppColors.chassisText,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
