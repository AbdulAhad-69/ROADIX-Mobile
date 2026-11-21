/// Immutable state representing an in-flight emergency triage session
class TriageState {
  final String? selectedFault;
  final double latitude;
  final double longitude;
  final String pickupAddress;
  final String? vehicleType;
  final String? licensePlate;
  final List<String> symptoms;
  final String notes;
  final bool isHighPriority;
  final bool isInLiveLane;
  final bool hazardsWorking;
  final String? activeRequestId;

  const TriageState({
    this.selectedFault,
    this.latitude = 23.8759,
    this.longitude = 90.3795,
    this.pickupAddress = '',
    this.vehicleType,
    this.licensePlate,
    this.symptoms = const [],
    this.notes = '',
    this.isHighPriority = false,
    this.isInLiveLane = false,
    this.hazardsWorking = true,
    this.activeRequestId,
  });

  TriageState copyWith({
    String? selectedFault,
    double? latitude,
    double? longitude,
    String? pickupAddress,
    String? vehicleType,
    String? licensePlate,
    List<String>? symptoms,
    String? notes,
    bool? isHighPriority,
    bool? isInLiveLane,
    bool? hazardsWorking,
    String? activeRequestId,
  }) {
    return TriageState(
      selectedFault: selectedFault ?? this.selectedFault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      symptoms: symptoms ?? this.symptoms,
      notes: notes ?? this.notes,
      isHighPriority: isHighPriority ?? this.isHighPriority,
      isInLiveLane: isInLiveLane ?? this.isInLiveLane,
      hazardsWorking: hazardsWorking ?? this.hazardsWorking,
      activeRequestId: activeRequestId ?? this.activeRequestId,
    );
  }

  /// Whether essential triage info is ready for mechanic dispatch
  bool get isReadyForDispatch =>
      selectedFault != null &&
      vehicleType != null &&
      latitude != 0.0 &&
      longitude != 0.0;

  Map<String, dynamic> toJson() {
    return {
      'selectedFault': selectedFault,
      'latitude': latitude,
      'longitude': longitude,
      'pickupAddress': pickupAddress,
      'vehicleType': vehicleType,
      'licensePlate': licensePlate,
      'symptoms': symptoms,
      'notes': notes,
      'isHighPriority': isHighPriority,
      'isInLiveLane': isInLiveLane,
      'hazardsWorking': hazardsWorking,
      'activeRequestId': activeRequestId,
    };
  }

  factory TriageState.fromJson(Map<String, dynamic> json) {
    return TriageState(
      selectedFault: json['selectedFault'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 23.8759,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 90.3795,
      pickupAddress: json['pickupAddress'] as String? ?? '',
      vehicleType: json['vehicleType'] as String?,
      licensePlate: json['licensePlate'] as String?,
      symptoms: (json['symptoms'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      notes: json['notes'] as String? ?? '',
      isHighPriority: json['isHighPriority'] as bool? ?? false,
      isInLiveLane: json['isInLiveLane'] as bool? ?? false,
      hazardsWorking: json['hazardsWorking'] as bool? ?? true,
      activeRequestId: json['activeRequestId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriageState &&
          runtimeType == other.runtimeType &&
          selectedFault == other.selectedFault &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          pickupAddress == other.pickupAddress &&
          vehicleType == other.vehicleType &&
          licensePlate == other.licensePlate &&
          notes == other.notes &&
          isHighPriority == other.isHighPriority &&
          isInLiveLane == other.isInLiveLane &&
          hazardsWorking == other.hazardsWorking &&
          activeRequestId == other.activeRequestId;

  @override
  int get hashCode => Object.hash(
        selectedFault,
        latitude,
        longitude,
        pickupAddress,
        vehicleType,
        licensePlate,
        notes,
        isHighPriority,
        isInLiveLane,
        hazardsWorking,
        activeRequestId,
      );
}
