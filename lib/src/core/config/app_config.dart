/// Application Configuration
///
/// Reads environment variables configured via `--dart-define` at compile time
/// and provides safe fallbacks for development.
class AppConfig {
  const AppConfig._();

  /// Supabase project URL
  static const String supabaseUrl = String.fromEnvironment(
    'ROADIX_SUPABASE_URL',
    defaultValue: 'https://rgzmoqpkugpcqfryrjkj.supabase.co',
  );

  /// Supabase public anonymous API key
  static const String supabaseAnonKey = String.fromEnvironment(
    'ROADIX_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Brh5ctiNGrTdmKlVG2sHwA_aFWPlkAt',
  );

  /// Free vector tile style URL (OpenFreeMap Liberty style)
  static const String mapStyleUrl = String.fromEnvironment(
    'ROADIX_MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

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

  /// Validates whether essential backend configuration is set
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether the application is running in production mode
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
