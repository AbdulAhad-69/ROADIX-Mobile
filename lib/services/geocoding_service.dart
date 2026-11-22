import 'dart:convert';
import 'dart:io';
import '../src/core/config/app_config.dart';

/// Service providing reverse-geocoding from GPS coordinates to human-readable addresses
class GeocodingService {
  const GeocodingService._();

  /// Reverse-geocodes GPS coordinates into a human-readable street or area address.
  /// Prioritizes the configured Geoapify Reverse Geocoding API with fallback
  /// to OpenStreetMap Nominatim and coordinate string.
  static Future<String> reverseGeocode(double lat, double lng) async {
    final apiKey = AppConfig.geoapifyApiKey;
    if (apiKey.isNotEmpty) {
      final client = HttpClient();
      try {
        final uri = Uri.parse(
          'https://api.geoapify.com/v1/geocode/reverse?lat=$lat&lon=$lng&apiKey=$apiKey',
        );
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final props = features.first['properties'] as Map<String, dynamic>?;
            final formatted = props?['formatted'] as String?;
            if (formatted != null && formatted.trim().isNotEmpty) {
              return formatted.trim();
            }
            final street = props?['street'] as String? ?? props?['name'] as String?;
            final suburb = props?['suburb'] as String? ?? props?['district'] as String?;
            final city = props?['city'] as String? ?? props?['county'] as String?;
            final rawState = props?['state'] as String?;
            final state = rawState?.replaceAll(RegExp(r'\s+Division$', caseSensitive: false), '').trim();

            final parts = <String>[];
            if (street != null && street.trim().isNotEmpty) {
              parts.add(street.trim());
            }
            if (suburb != null && suburb.trim().isNotEmpty && !parts.contains(suburb.trim())) {
              parts.add(suburb.trim());
            }
            if (city != null && city.trim().isNotEmpty && !parts.contains(city.trim())) {
              parts.add(city.trim());
            }
            if (state != null && state.isNotEmpty && !parts.any((p) => p.toLowerCase() == state.toLowerCase())) {
              parts.add(state);
            }

            if (parts.isNotEmpty) {
              return parts.join(', ');
            }
          }
        }
      } catch (_) {
        // Fallback below
      } finally {
        client.close();
      }
    }

    // OpenStreetMap Nominatim fallback
    final nominatimClient = HttpClient();
    nominatimClient.userAgent = 'ROADIX-Mobile/1.0';
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final req = await nominatimClient.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {
    } finally {
      nominatimClient.close();
    }

    // Default formatted roadside position with offline division detection
    final division = detectDivision(lat, lng);
    final regionPrefix = division.isNotEmpty ? '$division Region • ' : '';
    return '${regionPrefix}Roadside Position (${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E)';
  }

  /// Offline classification of coordinates across all 8 administrative divisions of Bangladesh.
  static String detectDivision(double lat, double lng) {
    if (lat >= 25.1 && lng < 90.0) return 'Rangpur';
    if (lat >= 24.0 && lng >= 91.2) return 'Sylhet';
    if (lat >= 24.2 && lat < 25.3 && lng >= 89.6 && lng < 91.2) return 'Mymensingh';
    if (lat >= 23.8 && lat < 25.1 && lng < 89.6) return 'Rajshahi';
    if (lat < 23.2 && lng >= 89.8 && lng < 90.9) return 'Barishal';
    if (lat < 24.3 && lng >= 90.8) return 'Chittagong';
    if (lat < 24.0 && lng < 89.8) return 'Khulna';
    if (lat >= 23.2 && lat <= 24.5 && lng >= 89.8 && lng <= 91.0) return 'Dhaka';
    return '';
  }
}
