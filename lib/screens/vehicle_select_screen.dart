import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../widgets/vehicle_editor_sheet.dart';
import 'fault_details_screen.dart';

class VehicleSelectScreen extends StatefulWidget {
  final String selectedFault;
  final double breakdownLat;
  final double breakdownLng;
  final String breakdownAddress;

  const VehicleSelectScreen({
    super.key,
    required this.selectedFault,
    this.breakdownLat = 23.8759,
    this.breakdownLng = 90.3795,
    this.breakdownAddress = 'Dhaka Region • Roadside Position',
  });

  static String mapUiCategoryToSrs(String uiCategory) {
    switch (uiCategory) {
      case 'Sedan / Hatch':
      case 'SUV / Micro':
      case 'Sedan':
      case 'SUV':
      case 'Passenger Car':
        return 'Passenger Car';
      case 'Motorcycle':
        return 'Motorcycle';
      case 'Commercial':
      case 'Light Commercial':
        return 'Light Commercial';
      default:
        return 'Passenger Car';
    }
  }

  @override
  State<VehicleSelectScreen> createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  final SupabaseService _db = SupabaseService();
  int _selectedVehicleTypeIndex = 1; // Default to Private Car / Sedan
  String _selectedFuelType = 'Octane';
  late final TextEditingController _plateController;
  List<Map<String, dynamic>> _savedVehicles = [];
  bool _isLoadingGarage = true;
  String? _selectedSavedVehicleId;

  final List<Map<String, dynamic>> _vehicleCategories = [
    {
      'title': 'Motorcycle',
      'subtitle': '2-Wheeler / Scooter',
      'icon': Icons.two_wheeler,
      'srsType': 'Motorcycle',
    },
    {
      'title': 'Sedan / Hatch',
      'subtitle': 'Private Passenger Car',
      'icon': Icons.directions_car,
      'srsType': 'Passenger Car',
    },
    {
      'title': 'SUV / Micro',
      'subtitle': '7-Seater / 4x4 Jeep',
      'icon': Icons.directions_car_filled,
      'srsType': 'Passenger Car',
    },
    {
      'title': 'Commercial',
      'subtitle': 'Pickup / Covered Van',
      'icon': Icons.local_shipping,
      'srsType': 'Light Commercial',
    },
  ];

  final List<String> _fuelTypes = ['Octane', 'Petrol', 'Diesel', 'CNG', 'EV'];

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: 'Dhaka Metro GA-11-2034');
    _loadSavedGarage();
  }

  Future<void> _loadSavedGarage() async {
    try {
      final vehicles = await _db.getVehicles();
      if (mounted) {
        setState(() {
          _savedVehicles = vehicles;
          _isLoadingGarage = false;
          if (vehicles.isNotEmpty) {
            final primary = vehicles.firstWhere(
              (v) => v['is_primary'] == true,
              orElse: () => vehicles.first,
            );
            _applyVehicleToForm(primary);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGarage = false);
    }
  }

  void _applyVehicleToForm(Map<String, dynamic> car) {
    _selectedSavedVehicleId = car['id']?.toString();
    _plateController.text = car['plate']?.toString() ?? '';
    _selectedFuelType = car['fuel']?.toString() ?? 'Octane';

    final srs = VehicleSelectScreen.mapUiCategoryToSrs(car['type']?.toString() ?? '');
    final matchIndex = _vehicleCategories.indexWhere((c) => c['srsType'] == srs);
    if (matchIndex != -1) {
      _selectedVehicleTypeIndex = matchIndex;
    }
  }

  void _openAddVehicleSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleEditorSheet(
        onSave: (savedData) async {
          await _db.addVehicle(
            model: savedData['model']!,
            plate: savedData['plate']!,
            type: savedData['type']!,
            fuel: savedData['fuel']!,
          );
          await _loadSavedGarage();
          if (mounted) {
            final updated = await _db.getVehicles();
            final newlyAdded = updated.firstWhere(
              (v) => v['plate'] == savedData['plate'],
              orElse: () => updated.isNotEmpty ? updated.last : {},
            );
            if (newlyAdded.isNotEmpty) {
              setState(() => _applyVehicleToForm(newlyAdded));
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
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
                  const Expanded(
                    child: Text(
                      'Vehicle Classification',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Step Progress: Step 2 of 4 (50%)
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
                        'STEP 2 OF 4',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'VEHICLE CLASSIFICATION',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
                        widthFactor: 0.50,
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

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 14.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Which vehicle needs assistance?',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigns mechanics certified for your vehicle type with exact diagnostic equipment for "${widget.selectedFault}".',
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Saved Vehicles Chips from Digital Garage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'SAVED DIGITAL GARAGE',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _openAddVehicleSheet,
                          child: const Text(
                            '+ Add Vehicle',
                            style: TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingGarage)
                      const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.caliperCrimson),
                          ),
                        ),
                      )
                    else if (_savedVehicles.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _savedVehicles.map((car) {
                            final isSelected = _selectedSavedVehicleId == car['id']?.toString() ||
                                _plateController.text.trim() == car['plate']?.toString().trim();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildSavedVehicleChip(
                                car['model']?.toString() ?? 'Vehicle',
                                car['plate']?.toString() ?? '',
                                isSelected,
                                () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _applyVehicleToForm(car));
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.slateBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'No saved vehicles in garage yet.',
                                style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _openAddVehicleSheet,
                              child: const Text(
                                'Save Now',
                                style: TextStyle(color: AppColors.caliperCrimson, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 22),

                    // 4-Card Vehicle Type Grid
                    const Text(
                      'OR SELECT CATEGORY',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vehicleCategories.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, index) {
                        final bool isSelected =
                            _selectedVehicleTypeIndex == index;
                        final item = _vehicleCategories[index];
                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedVehicleTypeIndex = index;
                              _selectedSavedVehicleId = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.crimsonLight.withAlpha(140)
                                  : AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.caliperCrimson
                                    : AppColors.slateBorder,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.caliperCrimson.withAlpha(16)
                                      : Colors.black.withAlpha(3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    VehicleIllustration(
                                      vehicleType: (item['srsType'] ?? item['title'] ?? 'Passenger Car') as String,
                                      size: 30,
                                    ),
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.caliperCrimson
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.caliperCrimson
                                              : AppColors.slateBorder,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 12,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        item['title'] as String,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.caliperCrimson
                                              : AppColors.chassisText,
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        item['subtitle'] as String,
                                        style: const TextStyle(
                                          color: AppColors.slateMuted,
                                          fontSize: 9.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // License Plate Number Field
                    const Text(
                      'LICENSE / REGISTRATION PLATE',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _plateController,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardWhite,
                        hintText: 'e.g., Dhaka Metro GA-11-2034',
                        hintStyle: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12,
                          fontFamily: 'sans-serif',
                        ),
                        prefixIcon: const Icon(Icons.pin, color: AppColors.slateMuted, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.slateBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.slateBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.caliperCrimson,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Fuel Type Chips
                    const Text(
                      'PROPULSION / FUEL TYPE',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _fuelTypes.map((fuel) {
                        final bool isSelected = _selectedFuelType == fuel;
                        return ChoiceChip(
                          label: Text(fuel),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedFuelType = fuel);
                            }
                          },
                          selectedColor: AppColors.caliperCrimson,
                          backgroundColor: AppColors.cardWhite,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.chassisText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.caliperCrimson
                                  : AppColors.slateBorder,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom CTA (Leads to Step 3)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(top: BorderSide(color: AppColors.slateBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final plate = _plateController.text.trim().isNotEmpty
                            ? _plateController.text.trim()
                            : 'Dhaka Metro GA-11-2034';

                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FaultDetailsScreen(
                              selectedFault: widget.selectedFault,
                              vehicleType: VehicleSelectScreen.mapUiCategoryToSrs(
                                _vehicleCategories[_selectedVehicleTypeIndex]['title']
                                    as String,
                              ),
                              licensePlate: plate,
                              breakdownLat: widget.breakdownLat,
                              breakdownLng: widget.breakdownLng,
                              breakdownAddress: widget.breakdownAddress,
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
                          Flexible(
                            child: Text(
                              'CONTINUE TO FAULT DETAILS',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
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
                  const Text(
                    'Step 2 of 4 • Next: Fault Diagnostics',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedVehicleChip(String name, String plate, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF2F2) : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.caliperCrimson
                : AppColors.slateBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
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
            Icon(
              Icons.directions_car,
              size: 14,
              color: isSelected
                  ? AppColors.caliperCrimson
                  : AppColors.slateMuted,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.caliperCrimson
                        : AppColors.chassisText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  plate,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 8.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
