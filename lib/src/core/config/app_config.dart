import 'dart:io';

/// Application Configuration
///
/// Dynamically reads environment variables from `.env` or compile-time
/// `--dart-define` / `--dart-define-from-file=.env` parameters.
class AppConfig {
  const AppConfig._();

  static final Map<String, String> _fileEnv = {};

  /// Loads configuration from the local `.env` file if accessible
  static Future<void> initialize() async {
    try {
      final file = File('.env');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final idx = trimmed.indexOf('=');
          if (idx > 0) {
            final key = trimmed.substring(0, idx).trim();
            final val = trimmed.substring(idx + 1).trim();
            _fileEnv[key] = val;
          }
        }
      }
    } catch (_) {}
  }

  /// Supabase project URL
  static String get supabaseUrl {
    if (_fileEnv.containsKey('EXPO_PUBLIC_SUPABASE_URL')) {
      return _fileEnv['EXPO_PUBLIC_SUPABASE_URL']!;
    }
    if (_fileEnv.containsKey('ROADIX_SUPABASE_URL')) {
      return _fileEnv['ROADIX_SUPABASE_URL']!;
    }
    return const String.fromEnvironment(
      'EXPO_PUBLIC_SUPABASE_URL',
      defaultValue: String.fromEnvironment(
        'ROADIX_SUPABASE_URL',
        defaultValue: 'https://rgzmoqpkugpcqfryrjkj.supabase.co',
      ),
    );
  }

  /// Supabase public anonymous API key
  static String get supabaseAnonKey {
    if (_fileEnv.containsKey('EXPO_PUBLIC_SUPABASE_ANON_KEY')) {
      return _fileEnv['EXPO_PUBLIC_SUPABASE_ANON_KEY']!;
    }
    if (_fileEnv.containsKey('ROADIX_SUPABASE_ANON_KEY')) {
      return _fileEnv['ROADIX_SUPABASE_ANON_KEY']!;
    }
    return const String.fromEnvironment(
      'EXPO_PUBLIC_SUPABASE_ANON_KEY',
      defaultValue: String.fromEnvironment(
        'ROADIX_SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnem1vcXBrdWdwY3FmcnlyamtqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5MDg0MjAsImV4cCI6MjEwNzQ4NDQyMH0.7uNmiq7vQPnnSqqOFmlcSFuouSq68gt_xRny2xKYmxI',
      ),
    );
  }

  /// Geoapify API key for map tiles, routing, and ETA
  static String get geoapifyApiKey {
    if (_fileEnv.containsKey('EXPO_PUBLIC_GEOAPIFY_API_KEY')) {
      return _fileEnv['EXPO_PUBLIC_GEOAPIFY_API_KEY']!;
    }
    if (_fileEnv.containsKey('GEOAPIFY_API_KEY')) {
      return _fileEnv['GEOAPIFY_API_KEY']!;
    }
    return const String.fromEnvironment(
      'EXPO_PUBLIC_GEOAPIFY_API_KEY',
      defaultValue: 'a27219f443524a94981907686734d6bb',
    );
  }

  /// Vector tile style URL (Geoapify OSM Bright Smooth style matching Showroom Porcelain)
  static String get mapStyleUrl {
    final key = geoapifyApiKey;
    if (key.isNotEmpty) {
      return 'https://maps.geoapify.com/v1/styles/osm-bright-smooth/style.json?apiKey=$key';
    }
    return 'https://tiles.openfreemap.org/styles/liberty';
  }

  /// Application title
  static const String appTitle = 'ROADIX';

  /// Initial mechanic search radius in kilometers
  static const double initialSearchRadiusKm = 5.0;

  /// Expansion search radius step in kilometers
  static const double expansionRadiusKm = 2.5;

  /// Dispatch acceptance timeout in seconds
  static const int dispatchTimeoutSeconds = 45;

  /// Emergency hotline number for Bangladesh
  static const String emergencyHotline = '999';

  /// SSLCommerz Sandbox Store ID
  static String get sslcommerzStoreId {
    if (_fileEnv.containsKey('SSLCOMMERZ_STORE_ID')) {
      return _fileEnv['SSLCOMMERZ_STORE_ID']!;
    }
    return const String.fromEnvironment(
      'SSLCOMMERZ_STORE_ID',
      defaultValue: 'roadi6aff1acc0bd78',
    );
  }

  /// SSLCommerz Sandbox Store Password
  static String get sslcommerzStorePassword {
    if (_fileEnv.containsKey('SSLCOMMERZ_STORE_PASSWD')) {
      return _fileEnv['SSLCOMMERZ_STORE_PASSWD']!;
    }
    return const String.fromEnvironment(
      'SSLCOMMERZ_STORE_PASSWD',
      defaultValue: '1MAu3twifTBj',
    );
  }

  /// Whether SSLCommerz is running in Sandbox mode
  static bool get sslcommerzIsSandbox {
    if (_fileEnv.containsKey('SSLCOMMERZ_IS_SANDBOX')) {
      return _fileEnv['SSLCOMMERZ_IS_SANDBOX']!.toLowerCase() == 'true';
    }
    return const bool.fromEnvironment(
      'SSLCOMMERZ_IS_SANDBOX',
      defaultValue: true,
    );
  }

  /// SSLCommerz Session Initiation URL
  static String get sslcommerzSessionUrl => sslcommerzIsSandbox
      ? 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php'
      : 'https://securepay.sslcommerz.com/gwprocess/v4/api.php';

  /// Cloudinary Cloud Name for CDN Asset Delivery
  static String get cloudinaryCloudName {
    if (_fileEnv.containsKey('CLOUDINARY_CLOUD_NAME')) {
      return _fileEnv['CLOUDINARY_CLOUD_NAME']!;
    }
    return const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: 'kefzjqi3',
    );
  }

  /// Google Web OAuth Client ID
  static String get googleWebClientId {
    if (_fileEnv.containsKey('EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID')) {
      return _fileEnv['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID']!;
    }
    return const String.fromEnvironment(
      'EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    );
  }

  /// Google Android OAuth Client ID
  static String get googleAndroidClientId {
    if (_fileEnv.containsKey('EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID')) {
      return _fileEnv['EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID']!;
    }
    return const String.fromEnvironment(
      'EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID',
      defaultValue: '',
    );
  }

  /// Indicates whether Google OAuth client credentials are configured
  static bool get isGoogleAuthConfigured {
    final web = googleWebClientId;
    final android = googleAndroidClientId;
    final isWebValid = web.isNotEmpty && !web.contains('your_google_');
    final isAndroidValid = android.isNotEmpty && !android.contains('your_google_');
    return isWebValid || isAndroidValid;
  }

  /// Validates whether essential backend configuration is set
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether the application is running in production mode
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}

