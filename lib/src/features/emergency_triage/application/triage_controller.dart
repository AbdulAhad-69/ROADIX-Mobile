import 'package:riverpod/riverpod.dart';
import '../domain/models/triage_state.dart';

/// StateNotifier that preserves emergency triage inputs across the multi-step wizard
class TriageController extends StateNotifier<TriageState> {
  TriageController() : super(const TriageState());

  static Map<String, dynamic>? _ephemeralDraft;

  /// Step 1: Select fault / emergency category
  void selectFault(String fault) {
    state = state.copyWith(selectedFault: fault);
    saveDraft();
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
    saveDraft();
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
    saveDraft();
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
    saveDraft();
  }

  /// Saves current triage state to ephemeral draft cache
  void saveDraft() {
    _ephemeralDraft = state.toJson();
  }

  /// Restores triage state from ephemeral draft cache if present
  bool restoreDraft() {
    if (_ephemeralDraft != null) {
      state = TriageState.fromJson(_ephemeralDraft!);
      return true;
    }
    return false;
  }

  /// Clears draft cache upon request completion or cancellation
  void clearDraft() {
    _ephemeralDraft = null;
    state = const TriageState();
  }

  /// Set the active dispatch / service request ID created in backend
  void setActiveRequestId(String id) {
    state = state.copyWith(activeRequestId: id);
    saveDraft();
  }

  /// Reset state when request completes or is cancelled
  void reset() {
    clearDraft();
  }
}

/// Provider for triage state management across navigation
final triageControllerProvider =
    StateNotifierProvider<TriageController, TriageState>((ref) {
  return TriageController();
});
