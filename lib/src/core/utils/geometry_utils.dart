import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Geometric & Spatial Telemetry Utilities for PostGIS point decoding,
/// Haversine distances, and dynamic urban ETA estimations.
class GeometryUtils {
  const GeometryUtils._();

  /// Decodes a PostGIS EWKB (Extended Well-Known Binary) hex string or GeoJSON map
  /// into a canonical `(lat, lng)` coordinate pair.
  static (double lat, double lng)? parsePostgisPoint(dynamic locationData) {
    if (locationData == null) return null;

    // 1. GeoJSON Map representation
    if (locationData is Map) {
      final coords = locationData['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        return (lat, lng);
      }
    }

    if (locationData is String) {
      final str = locationData.trim();
      // Handle JSON string format
      if (str.startsWith('{')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is Map) {
            return parsePostgisPoint(decoded);
          }
        } catch (_) {
          return null;
        }
      }

      // 2. EWKB Hex representation (e.g. 0101000020E6100000...)
      if (str.length < 42) return null;

      try {
        final bytes = <int>[];
        for (int i = 0; i < str.length; i += 2) {
          bytes.add(int.parse(str.substring(i, i + 2), radix: 16));
        }

        final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
        final isLittleEndian = byteData.getUint8(0) == 1;
        final endian = isLittleEndian ? Endian.little : Endian.big;

        final type = byteData.getUint32(1, endian);
        int offset = 5;
        // Check if SRID flag (0x20000000) is set
        if ((type & 0x20000000) != 0) {
          offset += 4; // Skip 4-byte SRID
        }

        final lng = byteData.getFloat64(offset, endian);
        final lat = byteData.getFloat64(offset + 8, endian);

        if (lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0) {
          return (lat, lng);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Calculates the great-circle distance between two GPS coordinates in kilometers
  /// using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculates estimated time of arrival (ETA) in minutes based on distance
  /// and average urban transit velocity (default: 20 km/h in Dhaka traffic).
  static int calculateEtaMinutes(
    double distanceKm, {
    double averageSpeedKmh = 20.0,
  }) {
    if (distanceKm <= 0) return 2;
    final hours = distanceKm / max(averageSpeedKmh, 5.0);
    final minutes = (hours * 60).round();
    return minutes.clamp(2, 90);
  }

  /// Formats distance and ETA for UI display, e.g. `~8 mins • 2.4 km away`
  static String formatEta(double distanceKm) {
    final eta = calculateEtaMinutes(distanceKm);
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '~$eta mins • ${meters}m away';
    }
    return '~$eta mins • ${distanceKm.toStringAsFixed(1)} km away';
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);
}
