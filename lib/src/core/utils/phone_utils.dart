import 'package:url_launcher/url_launcher.dart';

/// Phone number validation and normalization utilities for Bangladesh (+880)
class PhoneUtils {
  const PhoneUtils._();

  /// Normalizes any Bangladesh phone input into canonical E.164 format: `+8801XXXXXXXXX`.
  /// Accepts formats such as:
  /// - `01712345678` -> `+8801712345678`
  /// - `1712345678` -> `+8801712345678`
  /// - `+880 1712-345678` -> `+8801712345678`
  /// - `8801712345678` -> `+8801712345678`
  static String normalize(String raw) {
    // Strip all non-digit characters except leading plus
    String digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

    if (digits.startsWith('+880')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('880')) {
      digits = digits.substring(3);
    }

    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // A valid Bangladesh mobile number after stripping country code is 10 digits starting with 1
    // (e.g. 13, 14, 15, 16, 17, 18, 19)
    if (digits.length == 10 && digits.startsWith('1')) {
      return '+880$digits';
    }

    // If input was already fully formatted or partial, return best-effort E.164
    if (digits.isNotEmpty) {
      return '+880$digits';
    }
    return '';
  }

  /// Validates whether the given phone number conforms to Bangladesh mobile standards.
  static bool isValidBangladeshPhone(String raw) {
    final normalized = normalize(raw);
    // Exact format: +8801[3-9]XXXXXXXX (14 characters total: +880 plus 1 and 9 digits)
    final regex = RegExp(r'^\+8801[3-9]\d{8}$');
    return regex.hasMatch(normalized);
  }

  /// Formats a phone number for clean UI display: `+880 1712-345678`
  static String formatForDisplay(String raw) {
    final normalized = normalize(raw);
    if (normalized.length == 14 && normalized.startsWith('+880')) {
      final prefix = normalized.substring(0, 4); // +880
      final operatorAndFirst = normalized.substring(4, 8); // 1712
      final rest = normalized.substring(8); // 345678
      return '$prefix $operatorAndFirst-$rest';
    }
    return raw;
  }

  /// Creates a canonical telephony Uri (e.g. `tel:999` or `tel:+8801712345678`)
  static Uri createTelUri(String phoneOrHotline) {
    final trimmed = phoneOrHotline.trim();
    if (trimmed == '999') {
      return Uri.parse('tel:999');
    }
    final normalized = normalize(trimmed);
    return Uri.parse('tel:${normalized.isNotEmpty ? normalized : trimmed}');
  }

  /// Directly launches the device phone dialer with the target phone or emergency hotline
  static Future<bool> launchCall(String phoneOrHotline) async {
    final uri = createTelUri(phoneOrHotline);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
