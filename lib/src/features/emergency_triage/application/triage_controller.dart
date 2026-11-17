import 'package:riverpod/riverpod.dart';
import '../domain/models/triage_state.dart';

/// StateNotifier that preserves emergency triage inputs across the multi-step wizard
class TriageController extends StateNotifier<TriageState> {
  TriageController() : super(const TriageState());

  /// Step 1: Select fault / emergency category
  void selectFault(String fault) {
    state = state.copyWith(selectedFault: fault);
  }

  /// Step 2: Confirm breakdown GPS coordinates & textual address
  void updateLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      pickupAddress: address ?? state.pickupAddress,
    );
  }

  /// Step 3: Select vehicle type & license plate
  void selectVehicle({
    required String vehicleType,
    String? licensePlate,
  }) {
    state = state.copyWith(
      vehicleType: vehicleType,
      licensePlate: licensePlate ?? state.licensePlate,
    );
  }

  /// Step 4: Add diagnostic details, symptoms, hazard flags
  void updateFaultDetails({
    List<String>? symptoms,
    String? notes,
    bool? isInLiveLane,
    bool? hazardsWorking,
    bool? isHighPriority,
  }) {
    state = state.copyWith(
      symptoms: symptoms ?? state.symptoms,
      notes: notes ?? state.notes,
      isInLiveLane: isInLiveLane ?? state.isInLiveLane,
      hazardsWorking: hazardsWorking ?? state.hazardsWorking,
      isHighPriority: isHighPriority ?? state.isHighPriority,
    );
  }

  /// Set the active dispatch / service request ID created in backend
  void setActiveRequestId(String id) {
    state = state.copyWith(activeRequestId: id);
  }

  /// Reset state when request completes or is cancelled
  void reset() {
    state = const TriageState();
  }
}

/// Provider for triage state management across navigation
final triageControllerProvider =
    StateNotifierProvider<TriageController, TriageState>((ref) {
  return TriageController();
});
