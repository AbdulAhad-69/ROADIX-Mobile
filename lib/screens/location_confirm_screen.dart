import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import '../src/core/config/app_config.dart';
import '../src/core/models/geo_point.dart';
import '../theme/app_colors.dart';
import '../widgets/roadix_map_view.dart';
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
  RoadixMapController? _mapController;
  late RoadixGeoPoint _currentCenter;
  String _currentAddress = 'Roadside Position';
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
    _currentCenter = RoadixGeoPoint(widget.initialLat, widget.initialLng);
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
        final target = RoadixGeoPoint(pos.latitude, pos.longitude);
        final acc = pos.accuracy.round();
        setState(() {
          _currentCenter = target;
          _currentAccuracy = acc;
          _isManualPin = false;
        });
        _mapController?.animateCamera(target, zoom: 16.0);
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
    final target = RoadixGeoPoint(widget.initialLat, widget.initialLng);
    if (mounted) {
      setState(() {
        _currentCenter = target;
        _isManualPin = manual || widget.accuracyMeters == null;
        _currentAccuracy = widget.accuracyMeters;
      });
      _mapController?.animateCamera(target);
      _fetchAddress(target.latitude, target.longitude);
    }
  }

  String get _attributionLabel => AppConfig.hasGoogleMapsApiKey
      ? 'Google Maps'
      : (AppConfig.geoapifyApiKey.isNotEmpty
          ? '© OpenStreetMap • © Geoapify'
          : '© OpenStreetMap • © OpenFreeMap');

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
                          isLiveLock ? 'GPS Lock' : 'Manual Pin',
                          style: TextStyle(
                            color: isLiveLock
                                ? AppColors.emeraldDark
                                : AppColors.amberDark,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Step Progress Bar
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
                              ? 'Location Picker'
                              : 'Step 1 of 4',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.crimsonHover,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.isSelectingLocationOnly
                              ? 'Drag map pin'
                              : 'Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                    child: RoadixMapView(
                      initialCenter: _currentCenter,
                      initialZoom: 15.5,
                      onMapCreated: (ctrl) => _mapController = ctrl,
                      onCameraMove: (pos) {
                        final moved =
                            (pos.latitude - _currentCenter.latitude).abs() >
                                    0.00008 ||
                                (pos.longitude - _currentCenter.longitude)
                                        .abs() >
                                    0.00008;
                        if (moved && mounted) {
                          setState(() {
                            _currentCenter = pos;
                            _isManualPin = true;
                            _currentAccuracy = null;
                          });
                        }
                      },
                      onCameraIdle: () {
                        _scheduleGeocode(
                          _currentCenter.latitude,
                          _currentCenter.longitude,
                        );
                      },
                    ),
                  ),

                  // Fixed Center Target Pin
                  const IgnorePointer(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.caliperCrimson,
                          size: 42,
                        ),
                      ),
                    ),
                  ),

                  // Recenter to GPS Button (>= 48x48dp)
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
                          elevation: 2,
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

                  // Map Attribution
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
                          fontSize: 10.5,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(top: BorderSide(color: AppColors.slateBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              _isGeocoding ? 'Resolving address...' : _currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currentCenter.latitude.toStringAsFixed(4)}° N, ${_currentCenter.longitude.toStringAsFixed(4)}° E'
                              '${_currentAccuracy != null ? ' • ± ${_currentAccuracy}m' : ''}',
                              style: const TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 11.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
