import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VehicleEditorSheet extends StatefulWidget {
  final Map<String, String>? initialVehicle;
  final FutureOr<void> Function(Map<String, String> vehicle) onSave;
  final FutureOr<void> Function()? onDelete;

  const VehicleEditorSheet({
    super.key,
    this.initialVehicle,
    required this.onSave,
    this.onDelete,
  });

  static String normalizeToSrsCategory(String? type) {
    if (type == null) return 'Passenger Car';
    switch (type.trim().toLowerCase()) {
      case 'sedan':
      case 'suv':
      case 'passenger car':
      case 'sedan / hatch':
      case 'suv / micro':
        return 'Passenger Car';
      case 'motorcycle':
        return 'Motorcycle';
      case 'commercial':
      case 'light commercial':
        return 'Light Commercial';
      default:
        return 'Passenger Car';
    }
  }

  @override
  State<VehicleEditorSheet> createState() => _VehicleEditorSheetState();
}

class _VehicleEditorSheetState extends State<VehicleEditorSheet> {
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  late String _selectedType;
  late String _selectedFuel;

  final List<String> _vehicleTypes = [
    'Passenger Car',
    'Motorcycle',
    'Light Commercial',
  ];
  final List<String> _fuelTypes = ['Octane', 'Petrol', 'Diesel', 'CNG', 'EV'];

  bool get _isEditing => widget.initialVehicle != null;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.initialVehicle?['model'] ?? '');
    _plateController = TextEditingController(text: widget.initialVehicle?['plate'] ?? '');
    _selectedType = VehicleEditorSheet.normalizeToSrsCategory(widget.initialVehicle?['type']);
    _selectedFuel = widget.initialVehicle?['fuel'] ?? 'Octane';
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final model = _modelController.text.trim();
    final plate = _plateController.text.trim();

    if (model.isEmpty || plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both vehicle model and plate number.'),
          backgroundColor: AppColors.caliperCrimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSave({
        'model': model,
        'plate': plate,
        'type': VehicleEditorSheet.normalizeToSrsCategory(_selectedType),
        'fuel': _selectedFuel,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save vehicle: $e'),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slateBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _isEditing ? 'Edit Vehicle' : 'Add Vehicle to Garage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_isEditing && widget.onDelete != null)
                    IconButton(
                      tooltip: 'Delete vehicle',
                      icon: const Icon(Icons.delete_outline, color: AppColors.caliperCrimson, size: 22),
                      onPressed: () async {
                        await widget.onDelete!();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'VEHICLE TYPE',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _vehicleTypes.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = type);
                    },
                    selectedColor: AppColors.caliperCrimson,
                    backgroundColor: AppColors.porcelainBg,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.chassisText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

              const SizedBox(height: 14),

              const Text(
                'MAKE & MODEL',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _modelController,
                style: const TextStyle(color: AppColors.chassisText, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Toyota Allion, Yamaha FZS',
                  filled: true,
                  fillColor: AppColors.porcelainBg,
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

              const SizedBox(height: 14),

              const Text(
                'REGISTRATION PLATE',
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
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Dhaka Metro GA-11-2034',
                  filled: true,
                  fillColor: AppColors.porcelainBg,
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

              const SizedBox(height: 14),

              const Text(
                'FUEL / PROPULSION',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _fuelTypes.map((fuel) {
                  final isSelected = _selectedFuel == fuel;
                  return ChoiceChip(
                    label: Text(fuel),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFuel = fuel);
                    },
                    selectedColor: AppColors.caliperCrimson,
                    backgroundColor: AppColors.porcelainBg,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.chassisText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caliperCrimson,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isEditing ? 'UPDATE VEHICLE' : 'SAVE VEHICLE TO GARAGE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
}