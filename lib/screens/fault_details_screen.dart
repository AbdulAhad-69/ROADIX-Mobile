import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dispatch_screen.dart';

class FaultDetailsScreen extends StatefulWidget {
  final String selectedFault;
  final String vehicleType;
  final String licensePlate;
  final double breakdownLat;
  final double breakdownLng;
  final String breakdownAddress;

  const FaultDetailsScreen({
    super.key,
    required this.selectedFault,
    required this.vehicleType,
    required this.licensePlate,
    this.breakdownLat = 23.8759,
    this.breakdownLng = 90.3795,
    this.breakdownAddress = 'Dhaka Region • Roadside Position',
  });

  @override
  State<FaultDetailsScreen> createState() => _FaultDetailsScreenState();
}

class _FaultDetailsScreenState extends State<FaultDetailsScreen> {
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _selectedSymptoms = {};
  bool _isInLiveLane = false;
  bool _hazardsWorking = true;

  List<String> get _symptomOptions {
    switch (widget.selectedFault.toLowerCase()) {
      case 'dead battery':
        return [
          'Engine completely silent (no crank)',
          'Rapid clicking sound on ignition',
          'Dashboard lights dim or flickering',
          'I have jumper cables in vehicle',
        ];
      case 'flat tire':
        return [
          'Visible nail/screw puncture',
          'Tire shredded / blowout',
          'Working spare tire in trunk',
          'Lug wrench & jack available',
        ];
      case 'engine trouble':
        return [
          'Steam/smoke coming from hood',
          'Temperature gauge in red zone',
          'Engine stalling repeatedly',
          'Oil/fluid leaking beneath vehicle',
        ];
      case 'out of fuel':
        return [
          'Engine sputtered and died',
          'Fuel gauge reads empty',
          'Fuel can needed with delivery',
        ];
      case 'towing':
        return [
          'Vehicle cannot roll / wheels locked',
          'Transmission failure',
          'Severe collision damage',
          'Flatbed tow truck required',
        ];
      default:
        return [
          'Vehicle stalled unexpectedly',
          'Unusual grinding or knocking noise',
          'Electrical system failure',
          'Need diagnostic scanner on-site',
        ];
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Fault Diagnostics',
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

            // Step Progress: Step 3 of 4 (75%)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 3 OF 4',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'DEFECT QUESTIONNAIRE',
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
                        widthFactor: 0.75,
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

            // Scrollable Questionnaire
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Badge Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.crimsonLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.build, color: AppColors.caliperCrimson, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.selectedFault,
                                  style: const TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.vehicleType} • ${widget.licensePlate}',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Select Specific Symptoms',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap all that apply to help the dispatched mechanic pack parts',
                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 10),

                    // Symptom Checklist Cards
                    ..._symptomOptions.map((symptom) {
                      final bool isChecked = _selectedSymptoms.contains(symptom);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _selectedSymptoms.remove(symptom);
                              } else {
                                _selectedSymptoms.add(symptom);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: isChecked ? AppColors.crimsonLight.withAlpha(120) : AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isChecked ? AppColors.caliperCrimson : AppColors.slateBorder,
                                width: isChecked ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isChecked ? AppColors.caliperCrimson : AppColors.slateMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    symptom,
                                    style: TextStyle(
                                      color: isChecked ? AppColors.chassisText : const Color(0xFF334155),
                                      fontSize: 12,
                                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 18),

                    // Roadside Hazard Toggles
                    const Text(
                      'Roadside Safety Conditions',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Stranded in live highway lane',
                                    style: TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'High hazard risk: marks priority rescue',
                                    style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _isInLiveLane,
                                activeTrackColor: AppColors.caliperCrimson,
                                onChanged: (v) => setState(() => _isInLiveLane = v),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.slateBorder, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Hazard lights functioning',
                                    style: TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Vehicle visibility to oncoming traffic',
                                    style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _hazardsWorking,
                                activeTrackColor: AppColors.caliperCrimson,
                                onChanged: (v) => setState(() => _hazardsWorking = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Notes Field
                    const Text(
                      'Additional Notes (Optional)',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.chassisText, fontSize: 12.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardWhite,
                        hintText: 'e.g. Parked near Aarong gate, smells like burning rubber...',
                        hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.slateBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.slateBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom CTA
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
                            builder: (_) => DispatchScreen(
                              selectedFault: widget.selectedFault,
                              vehicleType: widget.vehicleType,
                              licensePlate: widget.licensePlate,
                              symptoms: _selectedSymptoms.toList(),
                              isHighPriority: _isInLiveLane,
                              breakdownLat: widget.breakdownLat,
                              breakdownLng: widget.breakdownLng,
                              breakdownAddress: widget.breakdownAddress,
                              diagnosticNotes: _notesController.text.trim(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caliperCrimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'FIND NEARBY MECHANICS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Step 3 of 4 • Next: Radar Dispatch & Telemetry',
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
}