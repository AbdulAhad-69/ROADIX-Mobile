import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileSetupScreen({super.key, required this.phoneNumber});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  String _selectedVehicleType = 'Passenger Car';
  String _selectedFuelType = 'Octane';
  bool _isSaving = false;

  final List<String> _vehicleTypes = [
    'Passenger Car',
    'Motorcycle',
    'Light Commercial',
  ];
  final List<String> _fuelTypes = ['Octane', 'Petrol', 'Diesel', 'CNG', 'EV'];

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      final model = _modelController.text.trim();
      final plate = _plateController.text.trim();

      await SupabaseService().createOrUpdateProfile(
        fullName: name.isNotEmpty ? name : 'Motorist',
        phone: widget.phoneNumber,
      );

      if (model.isNotEmpty && plate.isNotEmpty) {
        try {
          await SupabaseService().addVehicle(
            model: model,
            plate: plate,
            type: _selectedVehicleType,
            fuel: _selectedFuelType,
          );
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bypass Option
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finishSetup,
                  child: const Text(
                    'Set Up Later ›',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Complete Profile',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add your vehicle details for rapid roadside technician triage.',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),

              const SizedBox(height: 22),

              // Full Name
              const Text(
                'FULL NAME',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.chassisText, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.slateMuted, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Vehicle Category Chips
              const Text(
                'VEHICLE CATEGORY',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _vehicleTypes.map((type) {
                  final isSelected = _selectedVehicleType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedVehicleType = type);
                    },
                    selectedColor: AppColors.caliperCrimson,
                    backgroundColor: AppColors.cardWhite,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.chassisText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Make & Model
              const Text(
                'VEHICLE MAKE & MODEL',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _modelController,
                style: const TextStyle(color: AppColors.chassisText, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Toyota Corolla, Yamaha FZS',
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  prefixIcon: const Icon(Icons.directions_car_outlined, color: AppColors.slateMuted, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // License Plate
              const Text(
                'LICENSE / REGISTRATION PLATE',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _plateController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Dhaka Metro GA-11-2034',
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.slateMuted, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Fuel Type Chips
              const Text(
                'FUEL / PROPULSION TYPE',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _fuelTypes.map((fuel) {
                  final isSelected = _selectedFuelType == fuel;
                  return ChoiceChip(
                    label: Text(fuel),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFuelType = fuel);
                    },
                    selectedColor: AppColors.caliperCrimson,
                    backgroundColor: AppColors.cardWhite,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.chassisText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Save CTA
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _finishSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caliperCrimson,
                    disabledBackgroundColor: const Color(0xFFFCA5A5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'COMPLETE & ENTER ROADIX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}