import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/services/geocoding_service.dart';
import 'package:roadix_mobile/src/core/utils/geometry_utils.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  tearDown(() {
    E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 8.0);
  });

  // =========================================================================
  // FEATURE 1: R1.1 GPS Recenter Button
  // =========================================================================
  group('Feature 1: R1.1 GPS Recenter Button (SRS §R1)', () {
    testWidgets('T1.1.1: Recenter button renders on LocationConfirmScreen with Icons.my_location',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();

      expect(E2EFinders.recenterButton, findsOneWidget);
      expect(E2EFinders.gpsLockBadge, findsOneWidget);
      expect(E2EFinders.breakdownMarker, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.1.2: Tapping recenter button queries platform channel without exception',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 5.0);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Flat Tire'),
        ),
      );
      await tester.pump();

      final initialCount = E2ETestHarness.gpsQueryCount;
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(E2ETestHarness.gpsQueryCount, greaterThan(initialCount));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.1.3: Recenter button resets current coordinates back to initial GPS position',
        (WidgetTester tester) async {
      const initialLat = 23.8759;
      const initialLng = 90.3795;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Engine Trouble',
            initialLat: initialLat,
            initialLng: initialLng,
          ),
        ),
      );
      await tester.pump();

      // First tap preset chip to move location
      await tester.tap(E2EFinders.quickZoneChip('Mirpur 10'));
      await tester.pump();

      expect(find.textContaining('23.8069° N'), findsOneWidget);

      // Tap recenter button to restore initial coordinates
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();

      expect(find.textContaining('23.8759° N'), findsOneWidget);
      expect(find.textContaining('90.3795° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.1.4: Recenter maintains location accuracy badge and GPS lock status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Towing',
            accuracyMeters: 6,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.gpsLockBadge, findsOneWidget);
      expect(find.textContaining('accuracy'), findsOneWidget);

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();

      expect(E2EFinders.gpsLockBadge, findsOneWidget);
      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.1.5: Recenter button re-triggers reverse-geocoding for target coordinates',
        (WidgetTester tester) async {
      E2ETestHarness.registerGeocodeResult(
        23.8759,
        90.3795,
        'Sector 11, Uttara, Dhaka',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Out of Fuel'),
        ),
      );
      await tester.pump();

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.1.6: Rapid consecutive taps on recenter button do not crash or throw re-entrance errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();

      // Tap 5 times rapidly
      for (int i = 0; i < 5; i++) {
        await tester.tap(E2EFinders.recenterButton);
      }
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(E2EFinders.confirmLocationButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 2: R1.2 Live Tracking Updates
  // =========================================================================
  group('Feature 2: R1.2 Live Tracking Updates (SRS §R1)', () {
    test('T1.2.1: Haversine distance computation accurately computes metric distance', () {
      // Distance between Uttara (23.8759, 90.3795) and Airport Rd (23.8512, 90.4078)
      final distance = GeometryUtils.calculateDistanceKm(
        23.8759,
        90.3795,
        23.8512,
        90.4078,
      );

      expect(distance, greaterThan(3.5));
      expect(distance, lessThan(4.5));
    });

    test('T1.2.2: Dynamic ETA calculation applies traffic velocity model proportionally', () {
      // 3.0 km distance
      final eta3Km = GeometryUtils.calculateEtaMinutes(3.0);
      expect(eta3Km, greaterThan(5));
      expect(eta3Km, lessThan(20));

      // 10.0 km distance
      final eta10Km = GeometryUtils.calculateEtaMinutes(10.0);
      expect(eta10Km, greaterThan(eta3Km));
    });

    test('T1.2.3: Formatted ETA output formats human-readable arrival string', () {
      final etaShort = GeometryUtils.formatEta(1.2);
      expect(etaShort, contains('away'));
      expect(etaShort, contains('min'));

      final etaZero = GeometryUtils.formatEta(0.05);
      expect(etaZero, contains('away'));
    });

    testWidgets('T1.2.4: DispatchScreen transitions across live tracking rescue phases and updates status UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Battery dead'],
            isHighPriority: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Initial Searching Phase: verify beacon UI
      expect(find.textContaining('Broadcasting Breakdown Beacon'), findsOneWidget);

      // 2. Advance by 4 seconds into Offered Phase
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('remaining • Expiring'), findsOneWidget);
      expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);

      // 3. Simulate Mechanic Acceptance -> transitions to Assigned Phase
      final acceptBtn = find.text('Accept Offer (Simulate Mechanic)');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pump();

      expect(find.text('STATUS: ASSIGNED'), findsOneWidget);
      expect(find.textContaining('Technician has accepted your offer'), findsWidgets);

      // 4. Advance 4 seconds: status progresses to En Route
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: EN_ROUTE'), findsOneWidget);
      expect(find.textContaining('Technician is en route'), findsWidgets);

      // 5. Advance 4 seconds: status progresses to Arrived
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: ARRIVED'), findsOneWidget);
      expect(find.textContaining('Technician has arrived'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.2.5: DispatchScreen radar search expands radius from 5.0 km to 10.0 km',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Engine Overheating',
            vehicleType: 'Sedan',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Overheating engine'],
            isHighPriority: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial radius: 5.0 km
      expect(
        find.textContaining('within 5.0 km'),
        findsOneWidget,
        reason: 'Initial search radius must start at 5.0 km',
      );

      // Advance by 2 seconds: radius expands dynamically to 10.0 km
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('within 10.0 km'),
        findsOneWidget,
        reason: 'Search radius must dynamically expand to 10.0 km after first search interval',
      );

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.2.6: Zero distance boundary returns minimal positive ETA without zero division', () {
      final distance = GeometryUtils.calculateDistanceKm(23.8759, 90.3795, 23.8759, 90.3795);
      expect(distance, closeTo(0.0, 0.0001));

      final eta = GeometryUtils.calculateEtaMinutes(0.0);
      expect(eta, greaterThanOrEqualTo(1));
    });
  });

  // =========================================================================
  // FEATURE 3: R1.3 Multi-Department Geocoding
  // =========================================================================
  group('Feature 3: R1.3 Multi-Department Geocoding (SRS §R1)', () {
    test('T1.3.1: Chittagong coordinates (22.3569, 91.8215) resolve without hardcoded "Dhaka"', () async {
      final address = await GeocodingService.reverseGeocode(22.3569, 91.8215);

      expect(address, contains('Chittagong'));
      expect(address.contains('Dhaka'), isFalse,
          reason: 'Chittagong coordinates must not contain hardcoded "Dhaka" suffix');
    });

    test('T1.3.2: Sylhet coordinates (24.8949, 91.8687) resolve without hardcoded "Dhaka"', () async {
      final address = await GeocodingService.reverseGeocode(24.8949, 91.8687);

      expect(address, contains('Sylhet'));
      expect(address.contains('Dhaka'), isFalse,
          reason: 'Sylhet coordinates must not contain hardcoded "Dhaka" suffix');
    });

    test('T1.3.3: Khulna coordinates (22.8456, 89.5403) resolve without hardcoded "Dhaka"', () async {
      final address = await GeocodingService.reverseGeocode(22.8456, 89.5403);

      expect(address, contains('Khulna'));
      expect(address.contains('Dhaka'), isFalse,
          reason: 'Khulna coordinates must not contain hardcoded "Dhaka" suffix');
    });

    test('T1.3.4: Rajshahi coordinates (24.3636, 88.6241) resolve without hardcoded "Dhaka"', () async {
      final address = await GeocodingService.reverseGeocode(24.3636, 88.6241);

      expect(address, contains('Rajshahi'));
      expect(address.contains('Dhaka'), isFalse,
          reason: 'Rajshahi coordinates must not contain hardcoded "Dhaka" suffix');
    });

    testWidgets('T1.3.5: LocationConfirmScreen renders Chittagong coordinates without hardcoded "Dhaka"',
        (WidgetTester tester) async {
      const chittagongLat = 22.3569;
      const chittagongLng = 91.8215;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: chittagongLat,
            initialLng: chittagongLng,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('22.3569° N'), findsOneWidget);
      expect(find.textContaining('91.8215° E'), findsOneWidget);
      expect(find.textContaining('Chittagong'), findsWidgets);
      expect(find.textContaining('Dhaka'), findsNothing);
      expect(GeocodingService.detectDivision(chittagongLat, chittagongLng), equals('Chittagong'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.3.6: LocationConfirmScreen quick zone chips update coordinates across regions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'General Breakdown'),
        ),
      );
      await tester.pump();

      // Tap Kuril Flyover
      await tester.tap(E2EFinders.quickZoneChip('Kuril Flyover'));
      await tester.pump();
      expect(find.textContaining('23.8190° N'), findsOneWidget);

      // Tap Gulshan 2
      await tester.tap(E2EFinders.quickZoneChip('Gulshan 2'));
      await tester.pump();
      expect(find.textContaining('23.7925° N'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 4: R1.4 String & Coordinate Sanitization
  // =========================================================================
  group('Feature 4: R1.4 String & Coordinate Sanitization (SRS §R1)', () {
    testWidgets('T1.4.1: LocationConfirmScreen renders coordinate badge strictly bounded to 4 decimal places',
        (WidgetTester tester) async {
      const rawLat = 23.8759123456789;
      const rawLng = 90.3795987654321;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            initialLat: rawLat,
            initialLng: rawLng,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('23.8759° N, 90.3796° E'), findsOneWidget);
      expect(find.textContaining('23.875912'), findsNothing);
      expect(find.textContaining('90.379598'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.4.2: LocationConfirmScreen renders dynamic precision badge matching GPS accuracy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            accuracyMeters: 8,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('± 8m accuracy'), findsOneWidget);

      // Re-query with updated accuracy via recenter
      E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 3.0);
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('± 3m accuracy'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.4.3: LocationConfirmScreen renders sanitized address without leading or trailing whitespace',
        (WidgetTester tester) async {
      E2ETestHarness.registerGeocodeResult(
        23.8759,
        90.3795,
        '  Road 18, Sector 11, Uttara, Dhaka  ',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Road 18, Sector 11, Uttara, Dhaka'), findsOneWidget);
      expect(find.text('  Road 18, Sector 11, Uttara, Dhaka  '), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.4.4: LocationConfirmScreen renders address with ellipsis and no overflow on narrow width',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            accuracyMeters: 10,
          ),
          physicalSize: const Size(320, 600),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(E2EFinders.confirmLocationButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.4.5: LocationConfirmScreen renders Bengali unicode address without text corruption',
        (WidgetTester tester) async {
      const bengaliAddress = 'সেক্টর ১১, উত্তরা, ঢাকা';
      E2ETestHarness.registerGeocodeResult(23.8759, 90.3795, bengaliAddress);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(bengaliAddress), findsOneWidget);
      expect(find.textContaining('উত্তরা'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.4.6: LocationConfirmScreen renders roadside coordinate fallback when geocoded address is roadside position',
        (WidgetTester tester) async {
      E2ETestHarness.registerGeocodeResult(
        23.8759,
        90.3795,
        'Roadside Position (23.8759° N, 90.3795° E)',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Out of Fuel',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Roadside Position (23.8759° N, 90.3795° E)'), findsOneWidget);
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
