import '../src/core/config/app_config.dart';

/// Cloudinary Asset Delivery & CDN Management Service
///
/// Securely constructs optimized Cloudinary delivery URLs without exposing
/// sensitive API Secrets in client-side bundles. Follows Cloudinary best
/// practices: automatic format selection (`f_auto`), perceptual quality
/// optimization (`q_auto`), responsive scaling, and resilient local asset
/// fallbacks.
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  String get cloudName => AppConfig.cloudinaryCloudName;

  /// Builds an optimized CDN delivery URL for a given public ID or asset path.
  ///
  /// Applies automatic WebP/AVIF format transcoding (`f_auto`), smart lossy
  /// compression (`q_auto`), and dimension bounding.
  String getImageUrl(
    String publicIdOrPath, {
    int? width,
    int? height,
    String crop = 'fill',
    String format = 'auto',
    String quality = 'auto',
  }) {
    final cName = cloudName;
    if (cName.isEmpty || publicIdOrPath.isEmpty) {
      return '';
    }

    final List<String> transforms = [];
    if (format.isNotEmpty) transforms.add('f_$format');
    if (quality.isNotEmpty) transforms.add('q_$quality');
    if (width != null && width > 0) transforms.add('w_$width');
    if (height != null && height > 0) transforms.add('h_$height');
    if (crop.isNotEmpty && (width != null || height != null)) {
      transforms.add('c_$crop');
    }

    final transformSegment =
        transforms.isNotEmpty ? '${transforms.join(',')}/' : '';
    final cleanPath = publicIdOrPath.startsWith('/')
        ? publicIdOrPath.substring(1)
        : publicIdOrPath;

    return 'https://res.cloudinary.com/$cName/image/upload/$transformSegment$cleanPath';
  }

  /// Returns the CDN URL for official brand logos.
  String getBrandLogoUrl(String brand, {int size = 128}) {
    final normalized = brand.toLowerCase().trim();
    final path = 'roadix/brands/${normalized}_logo.png';
    return getImageUrl(path, width: size, height: size, crop: 'fit');
  }

  /// Returns the CDN URL for vehicle type illustrations.
  String getVehicleImageUrl(String vehicleType, {int size = 256}) {
    final normalized = _normalizeVehicleKey(vehicleType);
    final path = 'roadix/vehicles/$normalized.png';
    return getImageUrl(path, width: size, height: size, crop: 'fit');
  }

  /// Returns the CDN URL for roadside breakdown category imagery.
  String getServiceCategoryImageUrl(String category, {int size = 256}) {
    final normalized = _normalizeCategoryKey(category);
    final path = 'roadix/services/$normalized.png';
    return getImageUrl(path, width: size, height: size, crop: 'fit');
  }

  /// Maps a brand, vehicle, or service identifier to an authentic local asset fallback.
  static String getLocalAssetFallback(String identifier) {
    final key = identifier.toLowerCase().trim();
    if (key.contains('google')) return 'assets/images/google_logo.png';
    if (key.contains('bkash')) return 'assets/images/bkash_logo.png';
    if (key.contains('nagad')) return 'assets/images/nagad_logo.png';
    if (key.contains('sedan') || key.contains('car')) return 'assets/images/sedan.png';
    if (key.contains('suv')) return 'assets/images/suv.png';
    if (key.contains('motorcycle') || key.contains('bike')) return 'assets/images/motorcycle.png';
    if (key.contains('commercial') || key.contains('truck')) return 'assets/images/commercial.png';
    return 'assets/images/logo.png';
  }

  static String _normalizeVehicleKey(String vehicleType) {
    final lower = vehicleType.toLowerCase();
    if (lower.contains('suv')) return 'suv';
    if (lower.contains('motorcycle') || lower.contains('bike')) return 'motorcycle';
    if (lower.contains('commercial') || lower.contains('microbus')) return 'commercial';
    return 'sedan';
  }

  static String _normalizeCategoryKey(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('tire') || lower.contains('wheel')) return 'flat_tire';
    if (lower.contains('battery') || lower.contains('jumpstart')) return 'battery';
    if (lower.contains('engine') || lower.contains('overheat')) return 'engine';
    if (lower.contains('fuel')) return 'fuel';
    if (lower.contains('tow')) return 'towing';
    return 'general';
  }
}
