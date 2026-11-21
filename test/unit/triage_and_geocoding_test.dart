import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/src/features/emergency_triage/application/triage_controller.dart';
import 'package:roadix_mobile/src/features/emergency_triage/domain/models/triage_state.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';
import 'package:roadix_mobile/services/geocoding_service.dart';

void main() {
  group('TriageState JSON Serialization & Deserialization Tests', () {
    test('Serializes and deserializes full triage state correctly', () {
      const original = TriageState(
        selectedFault: 'Flat Tire',
        latitude: 23.8103,
        longitude: 90.4125,
        pickupAddress: 'Gulshan 2 Circle, Dhaka',
        vehicleType: 'Passenger Car',
        licensePlate: 'Dhaka Metro GA-11-2034',
        symptoms: ['Visible nail/screw puncture', 'Working spare tire in trunk'],
        notes: 'Parked in lane 3 with emergency hazards on',
        isHighPriority: true,
        isInLiveLane: true,
        hazardsWorking: true,
        activeRequestId: 'req-uuid-test',
      );

      final json = original.toJson();
      final restored = TriageState.fromJson(json);

      expect(restored.selectedFault, equals('Flat Tire'));
      expect(restored.latitude, equals(23.8103));
      expect(restored.longitude, equals(90.4125));
      expect(restored.pickupAddress, equals('Gulshan 2 Circle, Dhaka'));
      expect(restored.vehicleType, equals('Passenger Car'));
      expect(restored.licensePlate, equals('Dhaka Metro GA-11-2034'));
      expect(restored.symptoms.length, equals(2));
      expect(restored.isHighPriority, isTrue);
      expect(restored.isInLiveLane, isTrue);
      expect(restored.hazardsWorking, isTrue);
      expect(restored.activeRequestId, equals('req-uuid-test'));
      expect(restored, equals(original));
    });

    test('isReadyForDispatch requires fault, vehicle, and non-zero coordinates', () {
      const incomplete = TriageState(selectedFault: 'Dead Battery');
      expect(incomplete.isReadyForDispatch, isFalse);

      const complete = TriageState(
        selectedFault: 'Dead Battery',
        vehicleType: 'Motorcycle',
        latitude: 23.7500,
        longitude: 90.3800,
      );
      expect(complete.isReadyForDispatch, isTrue);
    });
  });

  group('TriageController Ephemeral Draft Cache Tests', () {
    test('Saves draft on each step and restores across simulation', () {
      final controller = TriageController();

      // Step 1: Select Fault
      controller.selectFault('Engine Overheat');
      expect(controller.state.selectedFault, equals('Engine Overheat'));

      // Step 2: Update Location
      controller.updateLocation(
        latitude: 23.8759,
        longitude: 90.3795,
        address: 'Sector 7, Uttara, Dhaka',
      );
      expect(controller.state.pickupAddress, equals('Sector 7, Uttara, Dhaka'));

      // Step 3: Select Vehicle
      controller.selectVehicle(
        vehicleType: 'Light Commercial',
        licensePlate: 'Dhaka Metro U-11-9988',
      );
      expect(controller.state.vehicleType, equals('Light Commercial'));

      // Step 4: Update Diagnostics
      controller.updateFaultDetails(
        symptoms: ['Steam/smoke coming from hood'],
        isInLiveLane: true,
        hazardsWorking: false,
        notes: 'Near airport roundabout',
      );

      // Simulate a fresh controller hydrating from the ephemeral draft
      final newController = TriageController();
      final hasDraft = newController.restoreDraft();

      expect(hasDraft, isTrue);
      expect(newController.state.selectedFault, equals('Engine Overheat'));
      expect(newController.state.pickupAddress, equals('Sector 7, Uttara, Dhaka'));
      expect(newController.state.vehicleType, equals('Light Commercial'));
      expect(newController.state.isInLiveLane, isTrue);
      expect(newController.state.notes, equals('Near airport roundabout'));

      // Reset clears the draft
      newController.reset();
      expect(newController.state.selectedFault, isNull);

      final thirdController = TriageController();
      expect(thirdController.restoreDraft(), isFalse);
    });
  });

  group('Guest SOS Callback Telephony Validation Tests', () {
    test('Normalizes Bangladesh mobile inputs for Guest SOS callback', () {
      expect(PhoneUtils.normalize('01712345678'), equals('+8801712345678'));
      expect(PhoneUtils.normalize('+880 1812-345678'), equals('+8801812345678'));
      expect(PhoneUtils.isValidBangladeshPhone(PhoneUtils.normalize('01712345678')), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone(PhoneUtils.normalize('01012345678')), isFalse);
    });
  });

  group('GeocodingService Address Fallback Tests', () {
    test('Falls back to formatted roadside position on null or empty API response', () async {
      // Coordinates outside internet should still produce clean roadside position
      final fallback = await GeocodingService.reverseGeocode(23.8759, 90.3795);
      expect(fallback.isNotEmpty, isTrue);
      expect(fallback.contains('23.8759') || fallback.contains('Dhaka') || fallback.contains('Uttara') || fallback.contains('Roadside'), isTrue);
    });
  });
}
