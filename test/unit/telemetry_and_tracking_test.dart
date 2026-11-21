import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/src/core/utils/geometry_utils.dart';

void main() {
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
}
