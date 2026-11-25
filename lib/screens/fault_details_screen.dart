import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'dispatch_screen.dart';

class FaultDetailsScreen extends StatefulWidget {
  final String selectedFault;
  final String vehicleType;
  final String licensePlate;
  final String fuelType;
  final double breakdownLat;
  final double breakdownLng;
  final String breakdownAddress;

  const FaultDetailsScreen({
    super.key,
    required this.selectedFault,
    required this.vehicleType,
    required this.licensePlate,
    this.fuelType = 'Octane',
    this.breakdownLat = 23.8759,
    this.breakdownLng = 90.3795,
    this.breakdownAddress = 'Dhaka Region • Roadside Position',
  });

  @override
  State<FaultDetailsScreen> createState() => _FaultDetailsScreenState();
}

class _FaultDetailsScreenState extends State<FaultDetailsScreen> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _selectedSymptoms = {};
  final List<String> _uploadedPhotoUrls = [];
  final List<Uint8List> _photoThumbnails = [];
  bool _isUploadingPhoto = false;
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

  Future<void> _pickAndUploadFaultPhoto(ImageSource source) async {
    if (_isUploadingPhoto || _uploadedPhotoUrls.length >= 3) return;
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final nameParts =
          (picked.name.isNotEmpty ? picked.name : picked.path).split('.');
      final ext = nameParts.length > 1 ? nameParts.last.toLowerCase() : 'jpg';

      if (mounted) setState(() => _isUploadingPhoto = true);
      final uploaded = await SupabaseService().uploadFaultPhoto(
        bytes,
        fileExtension: ext,
      );
      if (!mounted) return;
      if (uploaded != null && uploaded.isNotEmpty) {
        setState(() {
          _uploadedPhotoUrls.add(uploaded);
          _photoThumbnails.add(bytes);
          _isUploadingPhoto = false;
        });
      } else {
        setState(() => _isUploadingPhoto = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.crimsonHover,
        ),
      );
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
                  const Flexible(
                    child: Text(
                      'Fault Diagnostics',
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
                      Flexible(
                        child: Text(
                          'DEFECT QUESTIONNAIRE',
                          maxLines: 1,
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
                    // Flat Fault Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.crimsonLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.build,
                              color: AppColors.caliperCrimson,
                              size: 20,
                            ),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.vehicleType} • ${widget.fuelType} • ${widget.licensePlate}',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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

                    // Symptom Checklist Cards with Clear Tactile Selection States
                    ..._symptomOptions.map((symptom) {
                      final bool isChecked = _selectedSymptoms.contains(symptom);
                      final animDur = MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isChecked) {
                                _selectedSymptoms.remove(symptom);
                              } else {
                                _selectedSymptoms.add(symptom);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: animDur,
                            curve: const Cubic(0.23, 1, 0.32, 1),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isChecked ? AppColors.crimsonLight : AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isChecked ? AppColors.caliperCrimson : AppColors.slateBorder,
                                width: isChecked ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isChecked ? AppColors.caliperCrimson : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isChecked ? AppColors.caliperCrimson : AppColors.slateBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    symptom,
                                    style: TextStyle(
                                      color: isChecked ? AppColors.chassisText : const Color(0xFF334155),
                                      fontSize: 12.5,
                                      fontWeight: isChecked ? FontWeight.w800 : FontWeight.w500,
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

                    // Roadside Hazard Toggles with High-Visibility Urgent Hazard Styling
                    const Text(
                      'Roadside Safety Conditions',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: const Cubic(0.23, 1, 0.32, 1),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isInLiveLane
                            ? AppColors.crimsonLight
                            : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isInLiveLane
                              ? AppColors.caliperCrimson
                              : AppColors.slateBorder,
                          width: _isInLiveLane ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          MergeSemantics(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _isInLiveLane = !_isInLiveLane),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Stranded in live highway lane',
                                          style: TextStyle(
                                            color: AppColors.chassisText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'High hazard risk: marks priority rescue',
                                          style: TextStyle(
                                            color: AppColors.slateMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    value: _isInLiveLane,
                                    activeTrackColor:
                                        AppColors.caliperCrimson.withAlpha(120),
                                    activeThumbColor: AppColors.caliperCrimson,
                                    onChanged: (v) =>
                                        setState(() => _isInLiveLane = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isInLiveLane) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.crimsonHover,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Priority hazard dispatch activated for approaching mechanics.',
                                    style: TextStyle(
                                      color: AppColors.crimsonHover,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(color: AppColors.slateBorder, height: 16),
                          MergeSemantics(
                            child: InkWell(
                              onTap: () => setState(
                                () => _hazardsWorking = !_hazardsWorking,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hazard lights functioning',
                                          style: TextStyle(
                                            color: AppColors.chassisText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Vehicle visibility to oncoming traffic',
                                          style: TextStyle(
                                            color: AppColors.slateMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    value: _hazardsWorking,
                                    activeTrackColor:
                                        AppColors.caliperCrimson.withAlpha(120),
                                    activeThumbColor: AppColors.caliperCrimson,
                                    onChanged: (v) =>
                                        setState(() => _hazardsWorking = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Fault Photos (Uploaded via Cloudinary)
                    const Text(
                      'Damage or Warning Light Photos (Optional)',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: (_isUploadingPhoto || _uploadedPhotoUrls.length >= 3)
                                  ? null
                                  : () => _pickAndUploadFaultPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, size: 17),
                              label: const Text('Camera'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: (_isUploadingPhoto || _uploadedPhotoUrls.length >= 3)
                                  ? null
                                  : () => _pickAndUploadFaultPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 17),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isUploadingPhoto) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(color: AppColors.caliperCrimson),
                    ],
                    if (_photoThumbnails.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_photoThumbnails.length, (i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _photoThumbnails[i],
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _photoThumbnails.removeAt(i);
                                      _uploadedPhotoUrls.removeAt(i);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.chassisText,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],

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
                      style: const TextStyle(color: AppColors.chassisText, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Parked near Aarong gate, smells like burning rubber...',
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
                      onPressed: _isUploadingPhoto
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              final hazardNote = _hazardsWorking
                                  ? ''
                                  : '[Hazard lights non-functional] ';
                              final combinedNotes =
                                  'Fuel: ${widget.fuelType}. $hazardNote${_notesController.text.trim()}'
                                      .trim();
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
                                    diagnosticNotes: combinedNotes,
                                    photoUrls: List<String>.from(_uploadedPhotoUrls),
                                  ),
                                ),
                              );
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Flexible(
                            child: Text(
                              'FIND NEARBY MECHANICS',
                              maxLines: 1,
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