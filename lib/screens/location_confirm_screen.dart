import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../src/core/config/app_config.dart';
import '../theme/app_colors.dart';
import 'vehicle_select_screen.dart';

class LocationConfirmScreen extends StatefulWidget {
  final String selectedFault;
  final double initialLat;
  final double initialLng;
  final int accuracyMeters;

  const LocationConfirmScreen({
    super.key,
    required this.selectedFault,
    this.initialLat = 23.8759,
    this.initialLng = 90.3795,
    this.accuracyMeters = 8,
  });

  @override
  State<LocationConfirmScreen> createState() => _LocationConfirmScreenState();
}

class _LocationConfirmScreenState extends State<LocationConfirmScreen> {
  MapLibreMapController? _mapController;
  late LatLng _currentCenter;
  String get _styleUrl => AppConfig.mapStyleUrl;

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
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
                  const Text(
                    'Confirm Location',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                      onTap: () {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(widget.initialLat, widget.initialLng),
                          ),
                        );
                      },
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
                        child: const Icon(
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
                      Text(
                        'BREAKDOWN LOCATION',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Drag map to fine-tune',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                              'Dhaka Region • Roadside Position',
                              style: const TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${_currentCenter.latitude.toStringAsFixed(4)}° N, ${_currentCenter.longitude.toStringAsFixed(4)}° E',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
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
                                    '± ${widget.accuracyMeters}m accuracy',
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VehicleSelectScreen(
                              selectedFault: widget.selectedFault,
                              breakdownLat: _currentCenter.latitude,
                              breakdownLng: _currentCenter.longitude,
                              breakdownAddress: 'Dhaka Region • Roadside Position',
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'CONFIRM LOCATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Step 1 of 4 • Next: Vehicle Classification',
                      style: TextStyle(
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
}
