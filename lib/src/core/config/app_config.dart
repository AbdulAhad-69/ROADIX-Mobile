/// Compile-time application configuration injected via
/// `--dart-define` or `--dart-define-from-file=.env`.
///
/// Server secrets (SSLCommerz store password, Supabase service-role key,
/// Cloudinary API secrets) are intentionally excluded from client bundles and
/// remain strictly inside Supabase Edge Function secrets.
class AppConfig {
  const AppConfig._();

  static const String _expoSupabaseUrl =
      String.fromEnvironment('EXPO_PUBLIC_SUPABASE_URL');
  static const String _roadixSupabaseUrl =
      String.fromEnvironment('ROADIX_SUPABASE_URL');
  static const String _stdSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defaultSupabaseUrl =
      'https://rgzmoqpkugpcqfryrjkj.supabase.co';

  static const String _expoSupabaseAnonKey =
      String.fromEnvironment('EXPO_PUBLIC_SUPABASE_ANON_KEY');
  static const String _roadixSupabaseAnonKey =
      String.fromEnvironment('ROADIX_SUPABASE_ANON_KEY');
  static const String _stdSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnem1vcXBrdWdwY3FmcnlyamtqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5MDg0MjAsImV4cCI6MjEwNzQ4NDQyMH0.7uNmiq7vQPnnSqqOFmlcSFuouSq68gt_xRny2xKYmxI';

  static const String _expoGeoapifyKey =
      String.fromEnvironment('EXPO_PUBLIC_GEOAPIFY_API_KEY');
  static const String _stdGeoapifyKey =
      String.fromEnvironment('GEOAPIFY_API_KEY');
  static const String _mapStyleOverride =
      String.fromEnvironment('MAP_STYLE_URL');

  static const String _cloudinaryCloudEnv =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String _cloudinaryApiKeyEnv =
      String.fromEnvironment('CLOUDINARY_API_KEY');
  static const String _cloudinaryUploadPresetEnv =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
  static const String _googleMapsApiKeyEnv =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _mapsApiKeyEnv = String.fromEnvironment('MAPS_API_KEY');
  static const String _expoGoogleMapsApiKeyEnv =
      String.fromEnvironment('EXPO_PUBLIC_GOOGLE_MAPS_API_KEY');
  static const String _googleWebClientIdEnv =
      String.fromEnvironment('EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID');
  static const String _googleAndroidClientIdEnv =
      String.fromEnvironment('EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID');

  static String _firstNonEmpty(List<String> candidates) {
    for (final value in candidates) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  /// Retained as a safe no-op for startup and unit test lifecycle hooks.
  static Future<void> initialize() async {}

  /// Public Supabase project URL.
  static String get supabaseUrl => _firstNonEmpty([
        _expoSupabaseUrl,
        _roadixSupabaseUrl,
        _stdSupabaseUrl,
        _defaultSupabaseUrl,
      ]);

  /// Public Supabase anonymous key (row-level protected).
  static String get supabaseAnonKey => _firstNonEmpty([
        _expoSupabaseAnonKey,
        _roadixSupabaseAnonKey,
        _stdSupabaseAnonKey,
        _defaultSupabaseAnonKey,
      ]);

  /// Optional Geoapify API key injected at build time; empty when omitted.
  static String get geoapifyApiKey => _firstNonEmpty([
        _expoGeoapifyKey,
        _stdGeoapifyKey,
      ]);

  /// Vector tile style URL (custom override -> Geoapify if injected -> free OpenFreeMap Liberty).
  static String get mapStyleUrl {
    if (_mapStyleOverride.trim().isNotEmpty) {
      return _mapStyleOverride.trim();
    }
    final key = geoapifyApiKey;
    if (key.isNotEmpty) {
      return 'https://maps.geoapify.com/v1/styles/osm-bright-smooth/style.json?apiKey=$key';
    }
    return 'https://tiles.openfreemap.org/styles/liberty';
  }

  /// Application title.
  static const String appTitle = 'ROADIX';

  /// Supabase OAuth deep-link callback registered in AndroidManifest & Info.plist.
  static const String oauthRedirectUrl = 'io.supabase.roadix://login-callback';

  /// Initial mechanic search radius in kilometers.
  static const double initialSearchRadiusKm = 5.0;

  /// Expansion search radius step in kilometers.
  static const double expansionRadiusKm = 2.5;

  /// Dispatch acceptance timeout in seconds.
  static const int dispatchTimeoutSeconds = 45;

  /// Emergency hotline number for Bangladesh.
  static const String emergencyHotline = '999';

  /// Whether SSLCommerz runs in Sandbox mode (credentials stay server-side).
  static const bool sslcommerzIsSandbox = bool.fromEnvironment(
    'SSLCOMMERZ_IS_SANDBOX',
    defaultValue: true,
  );

  /// SSLCommerz Gateway Endpoint URL (for Edge Function / status verification).
  static String get sslcommerzSessionUrl => sslcommerzIsSandbox
      ? 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php'
      : 'https://securepay.sslcommerz.com/gwprocess/v4/api.php';

  /// Non-secret Cloudinary Cloud Name for public CDN asset formatting.
  static String get cloudinaryCloudName => _firstNonEmpty([
        _cloudinaryCloudEnv,
        'kefzjqi3',
      ]);

  /// Non-secret Cloudinary API key passed alongside server-generated SHA-1 signatures.
  static String get cloudinaryApiKey => _cloudinaryApiKeyEnv.trim();

  /// Optional Cloudinary unsigned upload preset configured in Cloudinary Console.
  static String get cloudinaryUploadPreset => _cloudinaryUploadPresetEnv.trim();

  /// Google Maps SDK API key injected via `--dart-define` / `.env` when configured.
  static String get googleMapsApiKey => _firstNonEmpty([
        _googleMapsApiKeyEnv,
        _mapsApiKeyEnv,
        _expoGoogleMapsApiKeyEnv,
      ]);

  /// Whether a native Google Maps API key is configured for `google_maps_flutter`.
  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;

  /// Deep-link callback URI registered for in-app SSLCommerz checkout completion.
  static const String paymentCallbackUrl = 'io.supabase.roadix://payment-callback';

  /// Optional Google Web OAuth Client ID.
  static String get googleWebClientId => _googleWebClientIdEnv.trim();

  /// Optional Google Android OAuth Client ID.
  static String get googleAndroidClientId => _googleAndroidClientIdEnv.trim();

  /// Google OAuth works via Supabase Auth PKCE/browser redirect whenever Supabase is configured.
  static bool get isGoogleAuthConfigured => isConfigured;

  /// Validates whether essential backend configuration is set.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether the application is running in production release mode.
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
