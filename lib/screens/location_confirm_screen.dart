import 'dart:async';
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
  final int? accuracyMeters;
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
  int? _currentAccuracy;
  bool _isManualPin = false;
  Timer? _geocodeDebounce;
  int _geocodeSeq = 0;

  @override
  void initState() {
    super.initState();
    _currentAccuracy = widget.accuracyMeters;
    _isManualPin = widget.accuracyMeters == null;
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    _fetchAddress(_currentCenter.latitude, _currentCenter.longitude);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _scheduleGeocode(double lat, double lng) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _fetchAddress(lat, lng);
    });
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    final seq = ++_geocodeSeq;
    setState(() => _isGeocoding = true);
    final addr = await GeocodingService.reverseGeocode(lat, lng);
    if (mounted && seq == _geocodeSeq) {
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
              content: Text(
                'Location services are disabled on your device. Please turn on GPS.',
              ),
              backgroundColor: AppColors.crimsonHover,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _fallbackToInitial(manual: true);
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
              content: Text(
                'Location permission denied. Showing preset location.',
              ),
              backgroundColor: AppColors.crimsonHover,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _fallbackToInitial(manual: true);
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
          _isManualPin = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
        _fetchAddress(pos.latitude, pos.longitude);
      } else {
        _fallbackToInitial(manual: true);
      }
    } catch (_) {
      _fallbackToInitial(manual: true);
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _fallbackToInitial({bool manual = false}) {
    final target = LatLng(widget.initialLat, widget.initialLng);
    if (mounted) {
      setState(() {
        _currentCenter = target;
        _isManualPin = manual || widget.accuracyMeters == null;
        _currentAccuracy = widget.accuracyMeters;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(target));
      _fetchAddress(target.latitude, target.longitude);
    }
  }

  String get _attributionLabel => AppConfig.geoapifyApiKey.isNotEmpty
      ? '© OpenStreetMap contributors • © Geoapify'
      : '© OpenStreetMap contributors • © OpenFreeMap';

  @override
  Widget build(BuildContext context) {
    final isLiveLock = !_isManualPin && _currentAccuracy != null;

    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
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
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLiveLock
                          ? AppColors.emeraldLight
                          : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLiveLock
                            ? AppColors.emeraldBorder
                            : AppColors.amberBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3.5,
                          backgroundColor: isLiveLock
                              ? AppColors.emeraldDark
                              : AppColors.amberDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLiveLock ? 'GPS LOCK' : 'MANUAL PIN',
                          style: TextStyle(
                            color: isLiveLock
                                ? AppColors.emeraldDark
                                : AppColors.amberDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Step Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.isSelectingLocationOnly
                              ? 'LOCATION PICKER'
                              : 'STEP 1 OF 4',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.crimsonHover,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.isSelectingLocationOnly
                              ? 'CUSTOM POSITION'
                              : 'LOCATION TRIAGE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 10.5,
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
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
                    'Drag the map to place the center pin exactly over your breakdown site.',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12,
                      height: 1.35,
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
                  Semantics(
                    label: 'Interactive breakdown map',
                    child: MapLibreMap(
                      styleString: _styleUrl,
                      trackCameraPosition: true,
                      compassEnabled: true,
                      myLocationEnabled: false,
                      minMaxZoomPreference: const MinMaxZoomPreference(5.0, 19.0),
                      initialCameraPosition: CameraPosition(
                        target: _currentCenter,
                        zoom: 15.5,
                      ),
                      onMapCreated: (ctrl) => _mapController = ctrl,
                      onCameraIdle: () {
                        final pos = _mapController?.cameraPosition?.target;
                        if (pos == null) return;
                        final moved = (pos.latitude - _currentCenter.latitude)
                                    .abs() >
                                0.00008 ||
                            (pos.longitude - _currentCenter.longitude).abs() >
                                0.00008;
                        if (moved) {
                          setState(() {
                            _currentCenter = pos;
                            _isManualPin = true;
                            _currentAccuracy = null;
                          });
                          _scheduleGeocode(pos.latitude, pos.longitude);
                        }
                      },
                    ),
                  ),

                  // Fixed Center Target Pin (non-blocking so user can drag smoothly underneath)
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: Column(
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
                                  color: Colors.black.withAlpha(80),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircleAvatar(
                                  radius: 3.5,
                                  backgroundColor: AppColors.caliperCrimson,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'BREAKDOWN POSITION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
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
                    ),
                  ),

                  // Recenter to GPS Button (>= 48x48dp accessible hit target)
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Semantics(
                      button: true,
                      label: 'Recenter map on current GPS position',
                      child: Tooltip(
                        message: 'Recenter to my GPS location',
                        child: Material(
                          color: AppColors.cardWhite,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _recenterToCurrentLocation,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.slateBorder),
                              ),
                              child: _isLocating
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.caliperCrimson,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      color: AppColors.caliperCrimson,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Dynamic Map Tiles Attribution
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite.withAlpha(235),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Text(
                        _attributionLabel,
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10,
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
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
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickZoneChip('Airport Rd', 23.8512, 90.4078),
                        _buildQuickZoneChip('Uttara Sec 7', 23.8732, 90.3980),
                        _buildQuickZoneChip('Kuril Flyover', 23.8190, 90.4200),
                        _buildQuickZoneChip('Mirpur 10', 23.8069, 90.3687),
                        _buildQuickZoneChip('Gulshan 2', 23.7985, 90.4143),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.crimsonLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pin_drop,
                          color: AppColors.crimsonHover,
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_currentCenter.latitude.toStringAsFixed(4)}° N, ${_currentCenter.longitude.toStringAsFixed(4)}° E',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLiveLock
                                        ? AppColors.emeraldLight
                                        : AppColors.surfaceTint,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isLiveLock
                                          ? AppColors.emeraldBorder
                                          : AppColors.slateBorder,
                                    ),
                                  ),
                                  child: Text(
                                    _isGeocoding
                                        ? 'resolving...'
                                        : (_currentAccuracy != null
                                            ? '± ${_currentAccuracy}m accuracy'
                                            : 'Manual Pin'),
                                    style: TextStyle(
                                      color: isLiveLock
                                          ? AppColors.emeraldDark
                                          : AppColors.slateMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('CONFIRM LOCATION'),
                            const SizedBox(width: 6),
                            Icon(
                              widget.isSelectingLocationOnly
                                  ? Icons.check
                                  : Icons.arrow_forward,
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
                        fontSize: 11,
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
      padding: const EdgeInsets.only(right: 8.0),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Select $label preset location',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            final target = LatLng(lat, lng);
            setState(() {
              _currentCenter = target;
              _isManualPin = true;
              _currentAccuracy = null;
            });
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15.5));
            _fetchAddress(lat, lng);
          },
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1.0,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.crimsonLight
                      : AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.caliperCrimson
                        : AppColors.slateBorder,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.crimsonHover
                        : AppColors.chassisText,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
