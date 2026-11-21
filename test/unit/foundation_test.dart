import 'package:test/test.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/src/core/errors/failure.dart';
import 'package:roadix_mobile/src/core/errors/result.dart';
import 'package:roadix_mobile/src/features/emergency_triage/application/triage_controller.dart';
import 'package:roadix_mobile/src/features/emergency_triage/domain/models/triage_state.dart';

void main() {
  group('AppConfig Unit Tests', () {
    test('default configuration provides valid backend and tile endpoints', () {
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
      expect(
        AppConfig.mapStyleUrl.contains('geoapify') ||
            AppConfig.mapStyleUrl.contains('openfreemap'),
        isTrue,
      );
      expect(AppConfig.initialSearchRadiusKm, equals(5.0));
      expect(AppConfig.expansionRadiusKm, equals(2.5));
      expect(AppConfig.dispatchTimeoutSeconds, equals(45));
      expect(AppConfig.emergencyHotline, equals('999'));
      expect(AppConfig.isConfigured, isTrue);
    });
  });

  group('Result and Failure Monad Unit Tests', () {
    test('Success branch correctly extracts data and maps values', () {
      const Result<int> result = Result.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);

      final mapped = result.map((value) => 'Value: $value');
      expect(mapped.dataOrNull, equals('Value: 42'));

      final value = result.when(
        success: (d) => d * 2,
        error: (_) => 0,
      );
      expect(value, equals(84));
    });

    test('Error branch correctly retains Failure type and propagates', () {
      const Failure failure = NetworkFailure('No internet connection');
      const Result<int> result = Result.error(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));

      final mapped = result.map((value) => 'Value: $value');
      expect(mapped.isError, isTrue);
      expect(mapped.failureOrNull, equals(failure));

      final value = result.when(
        success: (d) => d * 2,
        error: (f) => -1,
      );
      expect(value, equals(-1));
    });

    test('FlatMap chaining propagates values correctly', () {
      const Result<int> initial = Result.success(10);
      final chained = initial.flatMap((val) => Result.success(val * 3));
      expect(chained.dataOrNull, equals(30));

      const Result<int> failed = Result.error(ServerFailure('Down'));
      final chainFail = failed.flatMap((val) => Result.success(val * 3));
      expect(chainFail.isError, isTrue);
      expect(chainFail.failureOrNull?.message, equals('Down'));
    });
  });

  group('TriageController & TriageState Unit Tests', () {
    test('initial state has default coordinates and null fault', () {
      final controller = TriageController();
      expect(controller.state.selectedFault, isNull);
      expect(controller.state.latitude, equals(23.8759));
      expect(controller.state.longitude, equals(90.3795));
      expect(controller.state.isReadyForDispatch, isFalse);
    });

    test('multi-step triage preserves location, vehicle, and notes', () {
      final controller = TriageController();

      // Step 1: Select fault
      controller.selectFault('Flat Tire');
      expect(controller.state.selectedFault, equals('Flat Tire'));

      // Step 2: Set exact GPS coordinates & address
      controller.updateLocation(
        latitude: 23.7925,
        longitude: 90.4078,
        address: 'Gulshan 2, Dhaka',
      );
      expect(controller.state.latitude, equals(23.7925));
      expect(controller.state.longitude, equals(90.4078));
      expect(controller.state.pickupAddress, equals('Gulshan 2, Dhaka'));

      // Step 3: Select vehicle
      controller.selectVehicle(
        vehicleType: 'Car / Sedan',
        licensePlate: 'DHAKA-METRO-GA-11-2233',
      );
      expect(controller.state.vehicleType, equals('Car / Sedan'));
      expect(controller.state.licensePlate, equals('DHAKA-METRO-GA-11-2233'));

      // Step 4: Add diagnostic details
      controller.updateFaultDetails(
        symptoms: ['Punctured front-left tire'],
        notes: 'Near the traffic circle, vehicle on hazard lights',
        isInLiveLane: true,
        hazardsWorking: true,
        isHighPriority: true,
      );
      expect(controller.state.symptoms, contains('Punctured front-left tire'));
      expect(controller.state.notes, contains('traffic circle'));
      expect(controller.state.isInLiveLane, isTrue);
      expect(controller.state.isHighPriority, isTrue);
      expect(controller.state.isReadyForDispatch, isTrue);

      // Step 5: Assign active request id
      controller.setActiveRequestId('req-12345');
      expect(controller.state.activeRequestId, equals('req-12345'));

      // Reset
      controller.reset();
      expect(controller.state, equals(const TriageState()));
      expect(controller.state.isReadyForDispatch, isFalse);
    });
  });
}
