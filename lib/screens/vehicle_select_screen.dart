import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
  int _selectedVehicleTypeIndex = 1; // Default to Private Car / Sedan
  String _selectedFuelType = 'Octane';
  final TextEditingController _plateController = TextEditingController(
    text: 'Dhaka Metro GA-11-2034',
  );

  final List<Map<String, dynamic>> _vehicleCategories = [
    {
      'title': 'Motorcycle',
      'subtitle': '2-Wheeler / Scooter',
      'icon': Icons.two_wheeler,
    },
    {
      'title': 'Sedan / Hatch',
      'subtitle': 'Private Passenger Car',
      'icon': Icons.directions_car,
    },
    {
      'title': 'SUV / Micro',
      'subtitle': '7-Seater / 4x4 Jeep',
      'icon': Icons.directions_car_filled,
    },
    {
      'title': 'Commercial',
      'subtitle': 'Pickup / Covered Van',
      'icon': Icons.local_shipping,
    },
  ];

  final List<String> _fuelTypes = ['Octane', 'Petrol', 'Diesel', 'CNG', 'EV'];

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
                  const Text(
                    'Vehicle Classification',
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
                      Text(
                        'VEHICLE CLASSIFICATION',
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
                      'Helps us assign a technician with the correct tools for "${widget.selectedFault}".',
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Saved Vehicles Chips
                    const Text(
                      'SAVED GARAGE',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSavedVehicleChip(
                          'Toyota Allion',
                          'GA-11-2034',
                          true,
                        ),
                        const SizedBox(width: 8),
                        _buildSavedVehicleChip(
                          'Yamaha FZS',
                          'LA-24-9011',
                          false,
                        ),
                      ],
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
                            childAspectRatio: 1.45,
                          ),
                      itemBuilder: (context, index) {
                        final bool isSelected =
                            _selectedVehicleTypeIndex == index;
                        final item = _vehicleCategories[index];
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedVehicleTypeIndex = index),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.crimsonLight.withAlpha(120)
                                  : AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.caliperCrimson
                                    : AppColors.slateBorder,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      color: isSelected
                                          ? AppColors.caliperCrimson
                                          : AppColors.slateMuted,
                                      size: 24,
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.caliperCrimson,
                                        size: 16,
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.caliperCrimson
                                            : AppColors.chassisText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      item['subtitle'] as String,
                                      style: const TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 9.5,
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FaultDetailsScreen(
                              selectedFault: widget.selectedFault,
                              vehicleType: VehicleSelectScreen.mapUiCategoryToSrs(
                                _vehicleCategories[_selectedVehicleTypeIndex]['title']
                                    as String,
                              ),
                              licensePlate: _plateController.text,
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
                          Text(
                            'CONTINUE TO FAULT DETAILS',
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
                  const Text(
                    'Step 2 of 4 • Next: Defect Questionnaire',
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

  Widget _buildSavedVehicleChip(String name, String plate, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _plateController.text = plate),
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
          ),
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
