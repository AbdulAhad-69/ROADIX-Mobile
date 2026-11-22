import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/src/features/emergency_triage/application/triage_controller.dart';
import 'package:roadix_mobile/src/features/emergency_triage/domain/models/triage_state.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';
import 'package:roadix_mobile/services/geocoding_service.dart';

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );

    await AppConfig.initialize();
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Supabase already initialized or offline mock active
    }
  });
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

    test('detectDivision correctly classifies all 8 administrative divisions of Bangladesh', () {
      expect(GeocodingService.detectDivision(23.8103, 90.4125), equals('Dhaka'));
      expect(GeocodingService.detectDivision(22.3569, 91.7832), equals('Chittagong'));
      expect(GeocodingService.detectDivision(24.8949, 91.8687), equals('Sylhet'));
      expect(GeocodingService.detectDivision(22.8456, 89.5403), equals('Khulna'));
      expect(GeocodingService.detectDivision(24.3745, 88.6042), equals('Rajshahi'));
      expect(GeocodingService.detectDivision(22.7010, 90.3535), equals('Barishal'));
      expect(GeocodingService.detectDivision(25.7439, 89.2752), equals('Rangpur'));
      expect(GeocodingService.detectDivision(24.7471, 90.4203), equals('Mymensingh'));
    });

    test('Multi-division reverse geocoding fallback does not produce false Dhaka outside Dhaka', () async {
      final chittagong = await GeocodingService.reverseGeocode(22.3569, 91.7832);
      expect(chittagong, contains('Chittagong'));
      expect(chittagong.contains('Dhaka'), isFalse);

      final sylhet = await GeocodingService.reverseGeocode(24.8949, 91.8687);
      expect(sylhet, contains('Sylhet'));
      expect(sylhet.contains('Dhaka'), isFalse);

      final khulna = await GeocodingService.reverseGeocode(22.8456, 89.5403);
      expect(khulna, contains('Khulna'));
      expect(khulna.contains('Dhaka'), isFalse);

      final rajshahi = await GeocodingService.reverseGeocode(24.3745, 88.6042);
      expect(rajshahi, contains('Rajshahi'));
      expect(rajshahi.contains('Dhaka'), isFalse);

      final barishal = await GeocodingService.reverseGeocode(22.7010, 90.3535);
      expect(barishal, contains('Barishal'));
      expect(barishal.contains('Dhaka'), isFalse);

      final rangpur = await GeocodingService.reverseGeocode(25.7439, 89.2752);
      expect(rangpur, contains('Rangpur'));
      expect(rangpur.contains('Dhaka'), isFalse);

      final mymensingh = await GeocodingService.reverseGeocode(24.7471, 90.4203);
      expect(mymensingh, contains('Mymensingh'));
      expect(mymensingh.contains('Dhaka'), isFalse);
    });
  });

  group('DispatchScreen Search Location Formatting Tests', () {
    testWidgets('Renders natural grammar for fallback coordinates without corrupted bullet sentences', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Dead Battery',
              vehicleType: 'Passenger Car',
              licensePlate: 'Dhaka Metro GA-11-2034',
              symptoms: ['Battery dead'],
              isHighPriority: false,
              breakdownLat: 23.8759,
              breakdownLng: 90.3795,
              breakdownAddress: 'Roadside Position • 23.8759° N, 90.3795° E',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should display natural phrasing
      expect(
        find.textContaining('Querying verified mobile workshops within 5.0 km of your roadside location (23.8759° N, 90.3795° E)...'),
        findsOneWidget,
      );
      // Must NOT contain corrupted bullet inside sentence
      expect(
        find.textContaining('within 5.0 km of Roadside Position •'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Renders regional fallback cleanly in DispatchScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Engine Overheating',
              vehicleType: 'Passenger Car',
              licensePlate: 'Dhaka Metro GA-11-2034',
              symptoms: ['Overheating'],
              isHighPriority: false,
              breakdownLat: 22.3569,
              breakdownLng: 91.7832,
              breakdownAddress: 'Chittagong Region • Roadside Position (22.3569° N, 91.7832° E)',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Querying verified mobile workshops within 5.0 km of your roadside location in Chittagong Region (22.3569° N, 91.7832° E)...'),
        findsOneWidget,
      );
      expect(
        find.textContaining('within 5.0 km of Chittagong Region •'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Preserves verified street address unmodified in DispatchScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Flat Tire',
              vehicleType: 'Passenger Car',
              licensePlate: 'Dhaka Metro GA-11-2034',
              symptoms: ['Flat tire'],
              isHighPriority: false,
              breakdownLat: 23.7925,
              breakdownLng: 90.4078,
              breakdownAddress: 'Gulshan 2 Circle, Dhaka',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Querying verified mobile workshops within 5.0 km of Gulshan 2 Circle, Dhaka...'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
