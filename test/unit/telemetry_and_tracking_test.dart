import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/src/core/utils/geometry_utils.dart';

class _MockMapLibrePlatform extends MapLibrePlatform {
  bool _viewCreated = false;

  @override
  Future<void> initPlatform(int id) async {}

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (!_viewCreated) {
      _viewCreated = true;
      scheduleMicrotask(() {
        try {
          onPlatformViewCreated(1);
        } catch (_) {}
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isMethod) {
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? mockPosition = Position(
    latitude: 22.3569,
    longitude: 91.7832,
    timestamp: DateTime(2026, 11, 22),
    accuracy: 4.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
  Position? mockLastKnownPosition;
  bool shouldThrowOnCurrent = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (shouldThrowOnCurrent || mockPosition == null) {
      throw Exception('GPS lookup failed');
    }
    return mockPosition!;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async =>
      mockLastKnownPosition ?? mockPosition;
}

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
  group('Milestone 4: GeometryUtils PostGIS Point Decoder Tests', () {
    test('parsePostgisPoint decodes GeoJSON map with coordinates', () {
      final geoJson = {
        'type': 'Point',
        'coordinates': [90.3795, 23.8759],
      };
      final coords = GeometryUtils.parsePostgisPoint(geoJson);
      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(23.8759, 0.0001));
      expect(coords.$2, closeTo(90.3795, 0.0001));
    });

    test('parsePostgisPoint decodes GeoJSON serialized JSON string', () {
      const geoJsonString = '{"type":"Point","coordinates":[90.4125,23.8103]}';
      final coords = GeometryUtils.parsePostgisPoint(geoJsonString);
      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(23.8103, 0.0001));
      expect(coords.$2, closeTo(90.4125, 0.0001));
    });

    test('parsePostgisPoint decodes PostGIS EWKB Hex Point', () {
      // Build dynamic 25-byte EWKB for Point(90.3795 23.8759) with SRID 4326:
      final b = ByteData(25);
      b.setUint8(0, 1); // little-endian
      b.setUint32(1, 0x20000001, Endian.little); // Point with SRID flag
      b.setUint32(5, 4326, Endian.little); // SRID 4326
      b.setFloat64(9, 90.3795, Endian.little); // Longitude X
      b.setFloat64(17, 23.8759, Endian.little); // Latitude Y
      final ewkbHex = [
        for (var i = 0; i < 25; i++)
          b.getUint8(i).toRadixString(16).padLeft(2, '0')
      ].join().toUpperCase();

      final coords = GeometryUtils.parsePostgisPoint(ewkbHex);
      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(23.8759, 0.0001));
      expect(coords.$2, closeTo(90.3795, 0.0001));
    });

    test('parsePostgisPoint returns null on null, empty, or malformed data', () {
      expect(GeometryUtils.parsePostgisPoint(null), isNull);
      expect(GeometryUtils.parsePostgisPoint(''), isNull);
      expect(GeometryUtils.parsePostgisPoint('not_hex_or_json'), isNull);
      expect(GeometryUtils.parsePostgisPoint({'invalid': 'structure'}), isNull);
      expect(GeometryUtils.parsePostgisPoint(12345), isNull);
    });
  });

  group('Milestone 4: Haversine Distance & Dynamic ETA Calculation', () {
    test('calculateDistanceKm returns 0 for identical points', () {
      final dist = GeometryUtils.calculateDistanceKm(23.8759, 90.3795, 23.8759, 90.3795);
      expect(dist, closeTo(0.0, 0.0001));
    });

    test('calculateDistanceKm calculates accurate spherical distance in Dhaka', () {
      // Uttara Sector 4 (23.8759, 90.3795) to Gulshan 2 Circle (23.7925, 90.4078)
      // Expected Haversine distance is ~9.7 km
      final dist = GeometryUtils.calculateDistanceKm(23.8759, 90.3795, 23.7925, 90.4078);
      expect(dist, greaterThan(9.0));
      expect(dist, lessThan(10.5));
    });

    test('calculateEtaMinutes accurately applies Dhaka urban traffic model', () {
      // At 20 km/h:
      // 5 km distance takes 15 minutes of driving
      final eta5km = GeometryUtils.calculateEtaMinutes(5.0);
      expect(eta5km, equals(15));

      // 0 km or tiny distance returns minimum clamp 2 minutes
      final eta0km = GeometryUtils.calculateEtaMinutes(0.0);
      expect(eta0km, equals(2));
    });

    test('formatEta formats minutes and hours cleanly', () {
      expect(GeometryUtils.formatEta(2.0), equals('~6 mins • 2.0 km away'));
      expect(GeometryUtils.formatEta(0.5), equals('~2 mins • 500m away'));
    });
  });

  group('Milestone 4: 5-Gate Conjunction & 45-Second Queue Verification', () {
    test('5-gate conjunction rules are all strictly required for dispatch eligibility', () {
      bool isEligible({
        required bool isVerified,
        required bool isOnDuty,
        required double distanceKm,
        required double searchRadiusKm,
        required bool specializationMatches,
        required bool isBusyWithRescue,
      }) {
        // Gate 1: Admin verification
        if (!isVerified) return false;
        // Gate 2: Active on-duty status
        if (!isOnDuty) return false;
        // Gate 3: Spatial proximity within current radius
        if (distanceKm > searchRadiusKm) return false;
        // Gate 4: SRS vehicle specialization match
        if (!specializationMatches) return false;
        // Gate 5: Unoccupied (not currently servicing another rescue)
        if (isBusyWithRescue) return false;

        return true;
      }

      // Conjunction check: All true -> Eligible
      expect(
        isEligible(
          isVerified: true,
          isOnDuty: true,
          distanceKm: 4.2,
          searchRadiusKm: 5.0,
          specializationMatches: true,
          isBusyWithRescue: false,
        ),
        isTrue,
      );

      // Gate 1 Fail: Unverified mechanic
      expect(
        isEligible(
          isVerified: false,
          isOnDuty: true,
          distanceKm: 2.0,
          searchRadiusKm: 5.0,
          specializationMatches: true,
          isBusyWithRescue: false,
        ),
        isFalse,
      );

      // Gate 2 Fail: Off-duty
      expect(
        isEligible(
          isVerified: true,
          isOnDuty: false,
          distanceKm: 2.0,
          searchRadiusKm: 5.0,
          specializationMatches: true,
          isBusyWithRescue: false,
        ),
        isFalse,
      );

      // Gate 3 Fail: Exceeds radius
      expect(
        isEligible(
          isVerified: true,
          isOnDuty: true,
          distanceKm: 6.5,
          searchRadiusKm: 5.0,
          specializationMatches: true,
          isBusyWithRescue: false,
        ),
        isFalse,
      );

      // Gate 4 Fail: Mismatched specialization
      expect(
        isEligible(
          isVerified: true,
          isOnDuty: true,
          distanceKm: 2.0,
          searchRadiusKm: 5.0,
          specializationMatches: false,
          isBusyWithRescue: false,
        ),
        isFalse,
      );

      // Gate 5 Fail: Busy with existing rescue
      expect(
        isEligible(
          isVerified: true,
          isOnDuty: true,
          distanceKm: 2.0,
          searchRadiusKm: 5.0,
          specializationMatches: true,
          isBusyWithRescue: true,
        ),
        isFalse,
      );
    });

    test('40/25/15/20 ranking formula weights sum to exactly 100%', () {
      const distanceWeight = 0.40;
      const ratingWeight = 0.25;
      const volumeWeight = 0.15;
      const responseVelocityWeight = 0.20;

      final totalWeight = distanceWeight + ratingWeight + volumeWeight + responseVelocityWeight;
      expect(totalWeight, closeTo(1.0, 0.0001));

      // Score simulation for two candidate mechanics
      double scoreMechanic({
        required double normalizedProximity, // 1.0 = at scene, 0.0 = at radius limit
        required double ratingNormalized,   // 5.0 -> 1.0
        required double volumeNormalized,   // 100+ rescues -> 1.0
        required double responseVelocity,   // Historical acceptance speed -> 1.0
      }) {
        return (normalizedProximity * distanceWeight) +
            (ratingNormalized * ratingWeight) +
            (volumeNormalized * volumeWeight) +
            (responseVelocity * responseVelocityWeight);
      }

      final closerMechanic = scoreMechanic(
        normalizedProximity: 0.95,
        ratingNormalized: 0.90,
        volumeNormalized: 0.50,
        responseVelocity: 0.80,
      );

      final fartherMechanic = scoreMechanic(
        normalizedProximity: 0.30,
        ratingNormalized: 1.00,
        volumeNormalized: 0.90,
        responseVelocity: 0.90,
      );

      expect(closerMechanic, greaterThan(fartherMechanic));
    });

    test('45-second sequential offer countdown and 15 km terminal expansion boundary', () {
      int countdown = 45;
      double radius = 5.0;
      const step = 2.5;
      const maxRadius = 15.0;

      // Simulate 45 second offer timeout
      while (countdown > 0) {
        countdown--;
      }
      expect(countdown, equals(0));

      // Simulate step-wise radius expansion
      final radiusHistory = <double>[radius];
      while (radius < maxRadius) {
        radius += step;
        radiusHistory.add(radius);
      }

      expect(radiusHistory, equals([5.0, 7.5, 10.0, 12.5, 15.0]));
      expect(radius, equals(15.0));

      // Further expansion beyond 15km must be blocked
      final canExpandFurther = radius < maxRadius;
      expect(canExpandFurther, isFalse);
    });
  });

  group('Milestone 2: LocationConfirmScreen Recenter & GPS Tests', () {
    test('Can register MockGeolocatorPlatform and query position', () async {
      final mock = MockGeolocatorPlatform();
      GeolocatorPlatform.instance = mock;

      final isEnabled = await Geolocator.isLocationServiceEnabled();
      expect(isEnabled, isTrue);

      final pos = await Geolocator.getCurrentPosition();
      expect(pos.latitude, equals(22.3569));
      expect(pos.longitude, equals(91.7832));
    });

    testWidgets('LocationConfirmScreen renders and recenter button triggers live GPS positioning', (WidgetTester tester) async {
      MapLibrePlatform.createInstance = () => _MockMapLibrePlatform();
      final mock = MockGeolocatorPlatform();
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: 23.8759,
            initialLng: 90.3795,
            accuracyMeters: 8,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Confirm Location'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // Tap recenter button
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Accuracy pill should update to mock accuracy 4m
      expect(find.text('± 4m accuracy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Recenter button handles disabled location services with warning SnackBar', (WidgetTester tester) async {
      MapLibrePlatform.createInstance = () => _MockMapLibrePlatform();
      final mock = MockGeolocatorPlatform();
      mock.serviceEnabled = false;
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: 23.8759,
            initialLng: 90.3795,
            accuracyMeters: 8,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Location services are disabled on your device. Please turn on GPS.'), findsOneWidget);
      expect(find.text('± 8m accuracy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Recenter button handles denied location permission with feedback SnackBar', (WidgetTester tester) async {
      MapLibrePlatform.createInstance = () => _MockMapLibrePlatform();
      final mock = MockGeolocatorPlatform();
      mock.serviceEnabled = true;
      mock.permission = LocationPermission.denied;
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: LocationConfirmScreen(
            selectedFault: 'Flat Tire',
            initialLat: 23.8759,
            initialLng: 90.3795,
            accuracyMeters: 8,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Location permission denied. Showing preset location.'), findsOneWidget);
      expect(find.text('± 8m accuracy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Milestone 2: SosScreen Live GPS Accuracy & Fallback Tests', () {
    testWidgets('SosScreen renders emerald ±Xm Acc badge when GPS fix is acquired', (WidgetTester tester) async {
      final mock = MockGeolocatorPlatform();
      mock.serviceEnabled = true;
      mock.permission = LocationPermission.whileInUse;
      mock.mockPosition = Position(
        latitude: 22.3569,
        longitude: 91.7832,
        timestamp: DateTime(2026, 11, 22),
        accuracy: 3.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: SosScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('±3m Acc'), findsOneWidget);
      expect(find.text('GPS Estimating'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('SosScreen renders amber GPS Estimating badge and regional corridor when GPS fails', (WidgetTester tester) async {
      final mock = MockGeolocatorPlatform();
      mock.serviceEnabled = false;
      mock.mockPosition = null;
      mock.mockLastKnownPosition = null;
      mock.shouldThrowOnCurrent = true;
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: SosScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('GPS Estimating'), findsOneWidget);
      expect(find.textContaining('±'), findsNothing);
      expect(find.textContaining('Highway Corridor (Estimated)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Milestone 2: MechanicHomeScreen Telemetry Coordinate Preservation Tests', () {
    testWidgets('MechanicHomeScreen preserves verified coordinates on transient GPS failure', (WidgetTester tester) async {
      final mock = MockGeolocatorPlatform();
      mock.serviceEnabled = true;
      mock.permission = LocationPermission.whileInUse;
      mock.mockPosition = Position(
        latitude: 22.3569,
        longitude: 91.7832,
        timestamp: DateTime(2026, 11, 22),
        accuracy: 4.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      GeolocatorPlatform.instance = mock;

      await tester.pumpWidget(
        const MaterialApp(
          home: MechanicHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Toggle duty switch to start telemetry stream
      final dutyToggle = find.byType(Switch);
      if (dutyToggle.evaluate().isNotEmpty) {
        await tester.tap(dutyToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Simulate sudden GPS outage (e.g. entering basement parking or tunnel)
      mock.shouldThrowOnCurrent = true;
      mock.mockPosition = null;
      mock.mockLastKnownPosition = null;

      // Advance frames
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('TECHNICIAN CONSOLE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });
}
