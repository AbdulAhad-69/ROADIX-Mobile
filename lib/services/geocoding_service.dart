import 'dart:convert';
import 'dart:io';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../src/core/config/app_config.dart';
import '../src/core/models/geo_point.dart';
import '../src/core/utils/geometry_utils.dart';

/// Place / roadside facility returned by live Geoapify / Nominatim spatial search.
class RoadixPlaceResult {
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final bool isVerifiedWorkshop;
  final double distanceKm;

  const RoadixPlaceResult({
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.isVerifiedWorkshop = false,
    required this.distanceKm,
  });
}

/// Route payload returned by OSRM or Haversine straight-line fallback.
class RoadixRouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isRoadRouted;

  const RoadixRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isRoadRouted,
  });

  List<RoadixGeoPoint> get geoPoints =>
      points.map((p) => RoadixGeoPoint(p.latitude, p.longitude)).toList();
}

/// Reverse-geocoding, Bangladesh division classification, OSRM road routing,
/// and external Google Maps turn-by-turn URL construction.
class GeocodingService {
  const GeocodingService._();

  /// Builds a clean Google Maps turn-by-turn driving directions URL.
  static Uri buildGoogleMapsDirectionsUri({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
  }) {
    final params = <String, String>{
      'api': '1',
      'destination': '${destLat.toStringAsFixed(6)},${destLng.toStringAsFixed(6)}',
      'travelmode': 'driving',
    };
    if (originLat != null && originLng != null) {
      params['origin'] =
          '${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}';
    }
    return Uri.https('www.google.com', '/maps/dir/', params);
  }

  /// Fetches a real OSRM driving route polyline + distance/duration between two coordinates,
  /// gracefully falling back to Haversine straight-line geometry offline.
  static Future<RoadixRouteResult> fetchDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final fallbackKm =
        GeometryUtils.calculateDistanceKm(fromLat, fromLng, toLat, toLng);
    final fallbackMins = GeometryUtils.calculateEtaMinutes(fallbackKm);
    final fallback = RoadixRouteResult(
      points: [LatLng(fromLat, fromLng), LatLng(toLat, toLng)],
      distanceKm: fallbackKm,
      durationMinutes: fallbackMins,
      isRoadRouted: false,
    );

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat?overview=simplified&geometries=geojson',
      );
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final first = routes.first as Map<String, dynamic>;
          final coords =
              (first['geometry'] as Map<String, dynamic>?)?['coordinates']
                  as List?;
          if (coords != null && coords.length >= 2) {
            final points = coords.map((pair) {
              final list = pair as List;
              return LatLng(
                (list[1] as num).toDouble(),
                (list[0] as num).toDouble(),
              );
            }).toList();
            final distMeters = (first['distance'] as num?)?.toDouble();
            final durSeconds = (first['duration'] as num?)?.toDouble();
            return RoadixRouteResult(
              points: points,
              distanceKm:
                  distMeters != null ? distMeters / 1000.0 : fallbackKm,
              durationMinutes: durSeconds != null
                  ? (durSeconds / 60.0).ceil().clamp(1, 240)
                  : fallbackMins,
              isRoadRouted: true,
            );
          }
        }
      }
    } catch (_) {
      // Fallback to straight-line geometry offline or in test environments.
    } finally {
      client.close();
    }
    return fallback;
  }

  /// Reverse-geocodes GPS coordinates into a human-readable street or area address.
  static Future<String> reverseGeocode(double lat, double lng) async {
    final apiKey = AppConfig.geoapifyApiKey;
    if (apiKey.isNotEmpty) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final uri = Uri.parse(
          'https://api.geoapify.com/v1/geocode/reverse?lat=$lat&lon=$lng&apiKey=$apiKey',
        );
        final request = await client.getUrl(uri);
        final response =
            await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final props = features.first['properties'] as Map<String, dynamic>?;
            final formatted = props?['formatted'] as String?;
            if (formatted != null) {
              final cleaned = formatted.trim();
              if (cleaned.isNotEmpty) return cleaned;
            }
            final street =
                props?['street'] as String? ?? props?['name'] as String?;
            final suburb =
                props?['suburb'] as String? ?? props?['district'] as String?;
            final city =
                props?['city'] as String? ?? props?['county'] as String?;
            final rawState = props?['state'] as String?;
            final state = rawState
                ?.replaceAll(RegExp(r'\s+Division$', caseSensitive: false), '')
                .trim();

            final parts = <String>[];
            if (street != null && street.trim().isNotEmpty) {
              parts.add(street.trim());
            }
            if (suburb != null &&
                suburb.trim().isNotEmpty &&
                !parts.contains(suburb.trim())) {
              parts.add(suburb.trim());
            }
            if (city != null &&
                city.trim().isNotEmpty &&
                !parts.contains(city.trim())) {
              parts.add(city.trim());
            }
            if (state != null &&
                state.isNotEmpty &&
                !parts.any((p) => p.toLowerCase() == state.toLowerCase())) {
              parts.add(state);
            }
            if (parts.isNotEmpty) return parts.join(', ');
          }
        }
      } catch (_) {
      } finally {
        client.close();
      }
    }

    // OpenStreetMap Nominatim fallback
    final nominatimClient = HttpClient();
    nominatimClient.connectionTimeout = const Duration(seconds: 5);
    nominatimClient.userAgent = 'ROADIX-Mobile/1.0';
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final req = await nominatimClient.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          final cleaned = displayName.trim();
          if (cleaned.isNotEmpty) {
            return cleaned;
          }
        }
      }
    } catch (_) {
    } finally {
      nominatimClient.close();
    }

    final division = detectDivision(lat, lng);
    final regionPrefix = division.isNotEmpty ? '$division Region • ' : '';
    return '${regionPrefix}Roadside Position (${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E)';
  }

  /// Offline classification across Bangladesh's 8 divisions; returns `''` outside BD bounds.
  static String detectDivision(double lat, double lng) {
    if (lat < 20.5 || lat > 26.7 || lng < 88.0 || lng > 92.7) {
      return '';
    }
    if (lat >= 25.1 && lng < 90.0) return 'Rangpur';
    if (lat >= 24.0 && lng >= 91.2) return 'Sylhet';
    if (lat >= 24.2 && lat < 25.3 && lng >= 89.6 && lng < 91.2) {
      return 'Mymensingh';
    }
    if (lat >= 23.8 && lat < 25.1 && lng < 89.6) return 'Rajshahi';
    if (lat < 23.2 && lng >= 89.8 && lng < 90.9) return 'Barishal';
    if (lat < 24.3 && lng >= 90.8) return 'Chittagong';
    if (lat < 24.0 && lng < 89.8) return 'Khulna';
    if (lat >= 23.2 && lat <= 24.5 && lng >= 89.8 && lng <= 91.0) {
      return 'Dhaka';
    }
    return '';
  }

  /// Searches real nearby automotive workshops, fuel stations, hospitals, and
  /// police stations via Geoapify Places API (when key is configured) around
  /// `(lat, lng)`, sorted by Haversine distance.
  static Future<List<RoadixPlaceResult>> searchNearbyPlaces({
    required double lat,
    required double lng,
    String query = '',
    int limit = 15,
  }) async {
    final geoapifyKey = AppConfig.geoapifyApiKey;
    if (geoapifyKey.isEmpty) return [];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final cleanQuery = query.trim();
      final uri = cleanQuery.isNotEmpty
          ? Uri.https('api.geoapify.com', '/v1/geocode/search', {
              'text': cleanQuery,
              'bias': 'proximity:$lng,$lat',
              'filter': 'countrycode:bd',
              'limit': '$limit',
              'apiKey': geoapifyKey,
            })
          : Uri.https('api.geoapify.com', '/v2/places', {
              'categories':
                  'service.vehicle,commercial.gas,healthcare.hospital,service.police',
              'filter': 'circle:$lng,$lat,15000',
              'bias': 'proximity:$lng,$lat',
              'limit': '$limit',
              'apiKey': geoapifyKey,
            });

      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final features =
          data is Map ? (data['features'] as List? ?? const []) : const [];

      final results = <RoadixPlaceResult>[];
      for (final item in features) {
        if (item is! Map) continue;
        final props = item['properties'];
        if (props is! Map) continue;
        final pLat = (props['lat'] as num?)?.toDouble();
        final pLng = (props['lon'] as num?)?.toDouble();
        if (pLat == null || pLng == null) continue;

        final cats = (props['categories'] as List?)
                ?.map((e) => e.toString().toLowerCase())
                .join(',') ??
            '';
        final category = cats.contains('police')
            ? 'Police'
            : (cats.contains('hospital')
                ? 'Hospital'
                : (cats.contains('gas') ? 'Fuel & CNG' : 'Workshop'));

        final name = (props['name']?.toString().trim().isNotEmpty ?? false)
            ? props['name'].toString().trim()
            : (props['address_line1']?.toString().trim() ?? 'Roadside Point');
        final formatted =
            props['formatted']?.toString().trim() ??
                props['address_line2']?.toString().trim() ??
                '${pLat.toStringAsFixed(4)}, ${pLng.toStringAsFixed(4)}';
        final phoneRaw =
            (props['datasource'] is Map && props['datasource']['raw'] is Map)
                ? (props['datasource']['raw']['phone']?.toString() ?? '')
                : '';

        results.add(
          RoadixPlaceResult(
            name: name,
            category: category,
            address: formatted,
            latitude: pLat,
            longitude: pLng,
            phone: phoneRaw.isNotEmpty
                ? phoneRaw
                : (category == 'Police' ? '999' : ''),
            distanceKm: GeometryUtils.calculateDistanceKm(lat, lng, pLat, pLng),
          ),
        );
      }
      results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return results;
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }
}
