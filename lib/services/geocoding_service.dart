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
            final street = props?['street'] as String?;
            final district = props?['district'] as String? ?? props?['city'] as String?;
            if (street != null || district != null) {
              return [street, district, 'Dhaka'].whereType<String>().join(', ');
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

    // Default formatted roadside position
    return 'Roadside Position • ${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
  }
}
