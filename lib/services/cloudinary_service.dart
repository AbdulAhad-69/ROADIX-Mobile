import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../src/core/config/app_config.dart';

/// Structured result returned after a Cloudinary image upload succeeds.
class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final int bytes;
  final String format;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
    required this.format,
  });
}

/// Typed exception describing Cloudinary configuration or upload failures.
class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;

  const CloudinaryUploadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Signature payload provided by a server-side `cloudinary-sign` Edge Function
/// or explicit signing callback.
class CloudinarySignedParams {
  final String signature;
  final String timestamp;
  final String apiKey;
  final String cloudName;
  final String? folder;
  final String? publicId;

  const CloudinarySignedParams({
    required this.signature,
    required this.timestamp,
    required this.apiKey,
    required this.cloudName,
    this.folder,
    this.publicId,
  });
}

typedef CloudinarySignCallback = Future<CloudinarySignedParams> Function({
  required String folder,
  String? publicId,
});

/// Cloudinary Asset Delivery & Upload Service
///
/// Securely constructs optimized Cloudinary delivery URLs (`f_auto,q_auto`) and
/// uploads user images (avatars, fault photos) to Cloudinary via either an
/// unsigned upload preset or a server-signed `cloudinary-sign` payload so
/// API secrets never ship inside mobile binaries.
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  String get cloudName => AppConfig.cloudinaryCloudName;

  /// Computes a Cloudinary Upload API v1_1 SHA-1 signature.
  ///
  /// Follows Cloudinary's specification: sort all signed parameter entries
  /// lexicographically by key, join with `&`, append `apiSecret` directly,
  /// and hash with lowercase hex SHA-1.
  static String computeSignature({
    required Map<String, String> params,
    required String apiSecret,
  }) {
    final entries = params.entries
        .where((e) => e.value.isNotEmpty)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final serialized = entries.map((e) => '${e.key}=${e.value}').join('&');
    final digest = sha1.convert(utf8.encode('$serialized$apiSecret'));
    return digest.toString();
  }

  /// Uploads raw image bytes (`jpg`, `png`, `webp`) directly to Cloudinary's
  /// `/v1_1/<cloud_name>/image/upload` multipart endpoint.
  ///
  /// Resolution order:
  /// 1. [signUpload] callback (if supplied) -> signed upload.
  /// 2. Explicit [uploadPreset] or [AppConfig.cloudinaryUploadPreset] -> unsigned upload.
  /// 3. Authenticated Supabase Edge Function `cloudinary-sign` -> signed upload.
  Future<CloudinaryUploadResult> uploadImage(
    Uint8List bytes, {
    required String folder,
    String? fileName,
    String fileExtension = 'jpg',
    String? uploadPreset,
    CloudinarySignCallback? signUpload,
    HttpClient Function()? httpClientFactory,
  }) async {
    if (bytes.isEmpty) {
      throw const CloudinaryUploadException('Selected image file is empty.');
    }

    final cleanExt = fileExtension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (cleanExt) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final effectiveFileName =
        fileName ?? 'roadix_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    String targetCloud = cloudName;
    final fields = <String, String>{};

    if (signUpload != null) {
      final signed = await signUpload(folder: folder);
      if (signed.signature.trim().isEmpty ||
          signed.apiKey.trim().isEmpty ||
          signed.timestamp.trim().isEmpty) {
        throw const CloudinaryUploadException(
          'Cloudinary signature payload is incomplete.',
        );
      }
      targetCloud =
          signed.cloudName.trim().isNotEmpty ? signed.cloudName.trim() : targetCloud;
      fields['api_key'] = signed.apiKey.trim();
      fields['timestamp'] = signed.timestamp.trim();
      fields['signature'] = signed.signature.trim();
      fields['folder'] = (signed.folder ?? folder).trim();
      if (signed.publicId != null && signed.publicId!.trim().isNotEmpty) {
        fields['public_id'] = signed.publicId!.trim();
      }
    } else {
      final effectivePreset =
          (uploadPreset ?? AppConfig.cloudinaryUploadPreset).trim();
      if (effectivePreset.isNotEmpty) {
        fields['upload_preset'] = effectivePreset;
        fields['folder'] = folder;
      } else {
        final signed = await _requestEdgeSignature(folder: folder);
        targetCloud = signed.cloudName.trim().isNotEmpty
            ? signed.cloudName.trim()
            : targetCloud;
        fields['api_key'] = signed.apiKey.trim();
        fields['timestamp'] = signed.timestamp.trim();
        fields['signature'] = signed.signature.trim();
        fields['folder'] = (signed.folder ?? folder).trim();
        if (signed.publicId != null && signed.publicId!.trim().isNotEmpty) {
          fields['public_id'] = signed.publicId!.trim();
        }
      }
    }

    if (targetCloud.isEmpty) {
      throw const CloudinaryUploadException(
        'CLOUDINARY_CLOUD_NAME is not configured.',
      );
    }

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$targetCloud/image/upload');
    final boundary =
        '----RoadixCloudinaryBoundary${DateTime.now().microsecondsSinceEpoch}';
    final bodyBuilder = BytesBuilder(copy: false);

    for (final entry in fields.entries) {
      bodyBuilder.add(utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'
        '${entry.value}\r\n',
      ));
    }

    final contentType = safeExt == 'png'
        ? 'image/png'
        : (safeExt == 'webp' ? 'image/webp' : 'image/jpeg');
    bodyBuilder.add(utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="$effectiveFileName"\r\n'
      'Content-Type: $contentType\r\n\r\n',
    ));
    bodyBuilder.add(bytes);
    bodyBuilder.add(utf8.encode('\r\n--$boundary--\r\n'));

    final payload = bodyBuilder.toBytes();
    final client = (httpClientFactory ?? HttpClient.new)();
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.contentLength = payload.length;
      request.add(payload);

      final response =
          await request.close().timeout(const Duration(seconds: 25));
      final respBody = await response.transform(utf8.decoder).join();
      Map<String, dynamic>? decoded;
      try {
        final raw = jsonDecode(respBody);
        if (raw is Map<String, dynamic>) decoded = raw;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final secureUrl = decoded?['secure_url']?.toString().trim() ?? '';
        if (secureUrl.isEmpty) {
          throw const CloudinaryUploadException(
            'Cloudinary upload succeeded without returning secure_url.',
          );
        }
        return CloudinaryUploadResult(
          secureUrl: secureUrl,
          publicId: decoded?['public_id']?.toString() ?? '',
          bytes: (decoded?['bytes'] as num?)?.toInt() ?? bytes.length,
          format: decoded?['format']?.toString() ?? safeExt,
        );
      }

      final errorObj = decoded?['error'];
      final errorMsg = (errorObj is Map ? errorObj['message']?.toString() : null) ??
          'Cloudinary upload failed (HTTP ${response.statusCode}).';
      throw CloudinaryUploadException(
        errorMsg,
        statusCode: response.statusCode,
      );
    } on CloudinaryUploadException {
      rethrow;
    } catch (e) {
      throw CloudinaryUploadException(
        'Could not reach Cloudinary upload service: $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<CloudinarySignedParams> _requestEdgeSignature({
    required String folder,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        throw const CloudinaryUploadException(
          'Cloudinary upload requires sign-in or CLOUDINARY_UPLOAD_PRESET configuration.',
        );
      }
      final resp = await client.functions.invoke(
        'cloudinary-sign',
        body: {'folder': folder},
      );
      final data = resp.data;
      if (resp.status >= 200 && resp.status < 300 && data is Map) {
        final signature = data['signature']?.toString() ?? '';
        final timestamp = data['timestamp']?.toString() ?? '';
        final apiKey = data['api_key']?.toString() ?? AppConfig.cloudinaryApiKey;
        final cloud = data['cloud_name']?.toString() ?? cloudName;
        if (signature.isEmpty || timestamp.isEmpty || apiKey.isEmpty) {
          throw const CloudinaryUploadException(
            'Cloudinary signing function returned incomplete credentials.',
          );
        }
        return CloudinarySignedParams(
          signature: signature,
          timestamp: timestamp,
          apiKey: apiKey,
          cloudName: cloud,
          folder: data['folder']?.toString() ?? folder,
        );
      }
      final err = (data is Map ? data['error']?.toString() : null) ??
          'Cloudinary signing unavailable (HTTP ${resp.status}). Verify CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET.';
      throw CloudinaryUploadException(err, statusCode: resp.status);
    } on CloudinaryUploadException {
      rethrow;
    } catch (e) {
      throw CloudinaryUploadException(
        'Cloudinary upload failed: signing Edge Function unavailable ($e).',
      );
    }
  }

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
    final normalized = _normalizeBrandKey(brand);
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
    if (key.contains('upay')) return 'assets/images/upay_logo.png';
    if (key.contains('rocket') || key.contains('dbbl')) {
      return 'assets/images/rocket_logo.png';
    }
    if (key.contains('nexuspay') || key.contains('nexus')) {
      return 'assets/images/nexuspay_logo.png';
    }
    if (key.contains('ucash')) return 'assets/images/ucash_logo.png';
    if (key.contains('sedan') || key.contains('car')) {
      return 'assets/images/sedan.png';
    }
    if (key.contains('suv')) return 'assets/images/suv.png';
    if (key.contains('motorcycle') || key.contains('bike')) {
      return 'assets/images/motorcycle.png';
    }
    if (key.contains('commercial') ||
        key.contains('truck') ||
        key.contains('microbus')) {
      return 'assets/images/commercial.png';
    }
    return 'assets/images/logo.png';
  }

  static String _normalizeBrandKey(String brand) {
    final lower = brand.toLowerCase().trim();
    if (lower.contains('google')) return 'google';
    if (lower.contains('bkash')) return 'bkash';
    if (lower.contains('nagad')) return 'nagad';
    if (lower.contains('rocket') || lower.contains('dbbl')) return 'rocket';
    if (lower.contains('upay')) return 'upay';
    if (lower.contains('nexuspay') || lower.contains('nexus')) return 'nexuspay';
    if (lower.contains('ucash')) return 'ucash';
    return lower;
  }

  static String _normalizeVehicleKey(String vehicleType) {
    final lower = vehicleType.toLowerCase();
    if (lower.contains('suv')) return 'suv';
    if (lower.contains('motorcycle') || lower.contains('bike')) {
      return 'motorcycle';
    }
    if (lower.contains('commercial') || lower.contains('microbus')) {
      return 'commercial';
    }
    return 'sedan';
  }

  static String _normalizeCategoryKey(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('tire') || lower.contains('wheel')) return 'flat_tire';
    if (lower.contains('battery') || lower.contains('jumpstart')) {
      return 'battery';
    }
    if (lower.contains('engine') || lower.contains('overheat')) return 'engine';
    if (lower.contains('fuel')) return 'fuel';
    if (lower.contains('tow')) return 'towing';
    return 'general';
  }
}
