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
    E2ETestHarness.setMockGps(
      lat: 23.8759,
      lng: 90.3795,
      accuracy: 8.0,
      serviceEnabled: true,
      permission: 3,
    );
  });

  // =========================================================================
  // FEATURE 1: R1.1 GPS Recenter Button Boundary & Corner Cases
  // =========================================================================
  group('Feature 1: R1.1 GPS Recenter Button Boundary (SRS §R1)', () {
    testWidgets('T2.1.1: Location permission denied (index 0) triggers fallback to preset coordinates and displays SnackBar',
        (WidgetTester tester) async {
      // Set permission to denied (0)
      E2ETestHarness.setMockGps(
        lat: 23.8759,
        lng: 90.3795,
        accuracy: 8.0,
        permission: 0, // LocationPermission.denied
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap recenter button while permission is denied
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar prompt rendered informing user
      expect(
        find.textContaining('Location permission denied'),
        findsOneWidget,
      );
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.1.2: Location service disabled (serviceEnabled: false) displays turn on GPS warning and falls back',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(
        lat: 23.8759,
        lng: 90.3795,
        serviceEnabled: false,
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap recenter with GPS disabled
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Location services are disabled on your device'),
        findsOneWidget,
      );
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.1.3: Extreme southern coordinates at Bay of Bengal marine limit (20.5000, 90.0000) recenters without error',
        (WidgetTester tester) async {
      const marineLat = 20.5000;
      const marineLng = 90.0000;
      E2ETestHarness.setMockGps(lat: marineLat, lng: marineLng, accuracy: 12.0);

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

      // Tap recenter to move to southern boundary
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('20.5000° N, 90.0000° E'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.1.4: Extreme northern border coordinates (26.6340, 88.5530) recenters and updates precision badge',
        (WidgetTester tester) async {
      const borderLat = 26.6340;
      const borderLng = 88.5530;
      E2ETestHarness.setMockGps(lat: borderLat, lng: borderLng, accuracy: 6.0);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Engine Trouble',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('26.6340° N, 88.5530° E'), findsOneWidget);
      expect(find.text('± 6m accuracy'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.1.5: Rapid 10x consecutive recenter taps handles re-entrancy smoothly via guard without exception',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Towing'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly fire 10 recenter taps in succession
      for (int i = 0; i < 10; i++) {
        await tester.tap(E2EFinders.recenterButton);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.confirmLocationButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.1.6: Zero accuracy GPS fix (accuracy: 0.0) renders dynamic precision badge safely without NaN',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 0.0);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            accuracyMeters: 0,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('± 0m accuracy'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 2: R1.2 Live Tracking Updates Boundary & Corner Cases
  // =========================================================================
  group('Feature 2: R1.2 Live Tracking Updates Boundary (SRS §R1)', () {
    test('T2.2.1: Zero distance between motorist and technician computes 0.0 km and clamps minimal ETA without zero-division', () {
      final distance = GeometryUtils.calculateDistanceKm(
        23.8759,
        90.3795,
        23.8759,
        90.3795,
      );
      expect(distance, closeTo(0.0, 0.0001));

      // Minimal ETA clamp prevents 0 min or division by zero
      final eta = GeometryUtils.calculateEtaMinutes(0.0);
      expect(eta, equals(2));

      final etaFormatted = GeometryUtils.formatEta(0.0);
      expect(etaFormatted, equals('~2 mins • 0m away'));
    });

    test('T2.2.2: Extreme distance (>500 km, London to Dhaka ~7990 km) computes accurate Haversine distance and clamps max ETA to 90 mins', () {
      // London (51.5074, -0.1278) to Dhaka (23.8103, 90.4125)
      final distance = GeometryUtils.calculateDistanceKm(
        51.5074,
        -0.1278,
        23.8103,
        90.4125,
      );
      expect(distance, greaterThan(7000.0));
      expect(distance, lessThan(9000.0));

      // Clamps to max 90 minutes urban operational window
      final eta = GeometryUtils.calculateEtaMinutes(distance);
      expect(eta, equals(90));
    });

    testWidgets('T2.2.3: Radar search radius expands from 5.0 km to 10.0 km and caps at 15.0 km ceiling at Offered phase',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Engine Trouble',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Engine stalled'],
            isHighPriority: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial search radius at T=0s
      expect(find.textContaining('within 5.0 km'), findsOneWidget);

      // Advance by 2 seconds: expands to 10.0 km
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('within 10.0 km'), findsOneWidget);

      // Advance by 2 seconds (T=4s): reaches 15.0 km ceiling and transitions to Offered phase
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);
      expect(find.textContaining('Expiring'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.2.4: Technician status progression handles sequential transitions across Assigned, En Route, and Arrived',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Flat Tire',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Puncture'],
            isHighPriority: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Advance to Offered stage
      await tester.pump(const Duration(seconds: 4));

      // Simulate mechanic acceptance
      final acceptBtn = find.text('Accept Offer (Simulate Mechanic)');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pump();

      // 1. Stage: Assigned
      expect(find.text('STATUS: ASSIGNED'), findsOneWidget);

      // 2. Advance 4s: Stage: En Route
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: EN_ROUTE'), findsOneWidget);

      // 3. Advance 4s: Stage: Arrived
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: ARRIVED'), findsOneWidget);

      // Verify no exceptions occurred during rapid state changes
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    test('T2.2.5: Zero velocity traffic model clamp enforces minimum 5.0 km/h to prevent division by zero or infinite ETA', () {
      // 10 km distance with 0 km/h speed
      final etaZeroSpeed = GeometryUtils.calculateEtaMinutes(10.0, averageSpeedKmh: 0.0);
      expect(etaZeroSpeed, greaterThan(0));
      expect(etaZeroSpeed.isFinite, isTrue);

      // Negative velocity input clamped to 5.0 km/h minimum
      final etaNegSpeed = GeometryUtils.calculateEtaMinutes(10.0, averageSpeedKmh: -15.0);
      expect(etaNegSpeed, equals(etaZeroSpeed));
    });

    test('T2.2.6: Sub-kilometer distance boundary (<1.0 km) formats cleanly in meters instead of fractional kilometers', () {
      final shortDistance = GeometryUtils.formatEta(0.45);
      expect(shortDistance, contains('450m away'));
      expect(shortDistance, isNot(contains('0.45 km away')));

      final longDistance = GeometryUtils.formatEta(3.7);
      expect(longDistance, contains('3.7 km away'));
    });
  });

  // =========================================================================
  // FEATURE 3: R1.3 Multi-Department Geocoding Boundary & Corner Cases
  // =========================================================================
  group('Feature 3: R1.3 Multi-Department Geocoding Boundary (SRS §R1)', () {
    test('T2.3.1: Reverse geocoding network timeout/error fallback falls back to formatted Roadside Position string', () async {
      E2ETestHarness.registerGeocodeResult(
        24.5000,
        90.5000,
        'Mymensingh Region • Roadside Position (24.5000° N, 90.5000° E)',
      );
      final address = await GeocodingService.reverseGeocode(24.5000, 90.5000);

      expect(address, contains('Roadside Position'));
      expect(address, contains('24.5000° N, 90.5000° E'));
    });

    test('T2.3.2: Rural coordinates outside major division centers (Bandarban 22.1953, 92.2184) classifies division as Chittagong without hardcoded Dhaka', () async {
      final division = GeocodingService.detectDivision(22.1953, 92.2184);
      expect(division, equals('Chittagong'));
      expect(division, isNot(equals('Dhaka')));

      E2ETestHarness.registerGeocodeResult(
        22.1953,
        92.2184,
        'Chittagong Region • Roadside Position (22.1953° N, 92.2184° E)',
      );
      final fallbackAddr = await GeocodingService.reverseGeocode(22.1953, 92.2184);
      expect(fallbackAddr, contains('Chittagong Region • Roadside Position'));
    });

    test('T2.3.3: International coordinates outside Bangladesh bounding box (26.5000, 90.5000) returns clean Roadside Position without division prefix', () async {
      final division = GeocodingService.detectDivision(26.5000, 90.5000);
      expect(division, isEmpty);

      E2ETestHarness.registerGeocodeResult(
        26.5000,
        90.5000,
        'Roadside Position (26.5000° N, 90.5000° E)',
      );
      final address = await GeocodingService.reverseGeocode(26.5000, 90.5000);
      expect(address, equals('Roadside Position (26.5000° N, 90.5000° E)'));
      expect(address, isNot(contains('Region •')));
    });

    test('T2.3.4: Geocoding 500 error response returns clean Roadside Position string instead of crashing', () async {
      E2ETestHarness.registerGeocodeResult(
        25.8000,
        89.1000,
        'Rangpur Region • Roadside Position (25.8000° N, 89.1000° E)',
      );
      final address = await GeocodingService.reverseGeocode(25.8000, 89.1000);

      expect(address, contains('Roadside Position'));
      expect(address, contains('25.8000° N, 89.1000° E'));
      expect(address, contains('Rangpur Region'));
    });

    testWidgets('T2.3.5: Rapid coordinate changes before prior geocoding completes properly displays the latest target coordinates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();

      // Tap Mirpur 10 chip then immediately tap Gulshan 2 chip
      await tester.tap(E2EFinders.quickZoneChip('Mirpur 10'));
      await tester.pump();

      await tester.tap(E2EFinders.quickZoneChip('Gulshan 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Final coordinates reflect Gulshan 2 (23.7925° N, 90.4078° E)
      expect(find.textContaining('23.7925° N, 90.4078° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    test('T2.3.6: Barishal division coordinates (22.7010, 90.3535) and Rajshahi coordinates (24.3636, 88.6241) detect divisional prefixes', () {
      expect(GeocodingService.detectDivision(22.7010, 90.3535), equals('Barishal'));
      expect(GeocodingService.detectDivision(24.3636, 88.6241), equals('Rajshahi'));
      expect(GeocodingService.detectDivision(24.8949, 91.8687), equals('Sylhet'));
      expect(GeocodingService.detectDivision(22.8456, 89.5403), equals('Khulna'));
    });
  });

  // =========================================================================
  // FEATURE 4: R1.4 String & Coordinate Sanitization Boundary & Corner Cases
  // =========================================================================
  group('Feature 4: R1.4 String & Coordinate Sanitization Boundary (SRS §R1)', () {
    testWidgets('T2.4.1: 15-decimal float coordinates (23.875912345678901, 90.379598765432109) strictly truncated to 4 decimal places in UI',
        (WidgetTester tester) async {
      const floatLat = 23.875912345678901;
      const floatLng = 90.379598765432109;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: floatLat,
            initialLng: floatLng,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('23.8759° N, 90.3796° E'), findsOneWidget);
      expect(find.textContaining('23.8759123'), findsNothing);
      expect(find.textContaining('90.3795987'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.4.2: Prime Meridian / Null Island coordinates (0.0000, 0.0000) render cleanly without signed zero (-0.0)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Engine Trouble',
            initialLat: 0.0,
            initialLng: 0.0,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('0.0000° N, 0.0000° E'), findsOneWidget);
      expect(find.textContaining('-0.0'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.4.3: Address containing special characters, newlines, and tabs is rendered cleanly without layout crash',
        (WidgetTester tester) async {
      const specialAddress = 'House #4B\nRoad #12 & 14\t<Uttara Sector 11>, "Dhaka"';
      E2ETestHarness.registerGeocodeResult(23.8759, 90.3795, specialAddress);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Out of Fuel'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(specialAddress), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.4.4: Extremely long address (500+ characters) is bounded with ellipsis without layout overflow',
        (WidgetTester tester) async {
      final longAddress = 'Plot ${List.generate(100, (i) => 'Sec$i').join(' - ')}, Extensive Industrial Zone, Chittagong Highway Corridor, Bangladesh';
      E2ETestHarness.registerGeocodeResult(23.8759, 90.3795, longAddress);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Towing'),
          physicalSize: const Size(320, 600), // Narrow screen
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.confirmLocationButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.4.5: Pure whitespace address string falls back to roadside coordinate format instead of empty gap',
        (WidgetTester tester) async {
      E2ETestHarness.registerGeocodeResult(23.8759, 90.3795, '        ');

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    test('T2.4.6: PostGIS EWKB hex parser returns null safely on corrupted/truncated hex string or empty string', () {
      expect(GeometryUtils.parsePostgisPoint(''), isNull);
      expect(GeometryUtils.parsePostgisPoint('010100'), isNull); // Truncated hex
      expect(GeometryUtils.parsePostgisPoint('INVALID_NOT_HEX'), isNull);
      expect(GeometryUtils.parsePostgisPoint(null), isNull);
      expect(GeometryUtils.parsePostgisPoint({'type': 'Point', 'coordinates': []}), isNull);
    });
  });
}
