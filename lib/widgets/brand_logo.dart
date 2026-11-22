import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_colors.dart';

/// Reusable Brand Logo and Asset Component
///
/// Seamlessly loads official brand assets from Cloudinary CDN using optimized
/// transformations (`f_auto,q_auto`), with immediate local asset fallback
/// and stylized iconography for offline/air-gapped resilience.
class BrandLogo extends StatelessWidget {
  final String brand;
  final double size;
  final BoxFit fit;
  final Color? fallbackColor;
  final bool showBadge;

  const BrandLogo({
    super.key,
    required this.brand,
    this.size = 24.0,
    this.fit = BoxFit.contain,
    this.fallbackColor,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final key = brand.toLowerCase();
    if (!showBadge && key.contains('bkash')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: const BkashOrigamiBirdPainter(isBadgeMode: false),
        ),
      );
    }

    final cdnUrl = CloudinaryService().getBrandLogoUrl(brand, size: (size * 2).round());
    final localFallback = CloudinaryService.getLocalAssetFallback(brand);

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        cdnUrl,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            localFallback,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return _buildVectorFallback();
            },
          );
        },
      ),
    );
  }

  Widget _buildVectorFallback() {
    final key = brand.toLowerCase();
    if (key.contains('bkash')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: BkashOrigamiBirdPainter(isBadgeMode: showBadge),
        ),
      );
    } else if (key.contains('nagad')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF7941D),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Text(
            'N',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    } else if (key.contains('google')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.slateBorder),
        ),
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              color: const Color(0xFF4285F4),
              fontSize: size * 0.6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    } else if (key.contains('rocket')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF8C3494),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Text(
            'R',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return Icon(
      Icons.account_balance_wallet,
      size: size * 0.8,
      color: fallbackColor ?? AppColors.slateMuted,
    );
  }
}

/// Roadside Breakdown Service Category Illustration
class ServiceCategoryIllustration extends StatelessWidget {
  final String category;
  final double size;
  final BoxFit fit;
  final Color? fallbackColor;

  const ServiceCategoryIllustration({
    super.key,
    required this.category,
    this.size = 36.0,
    this.fit = BoxFit.contain,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final cdnUrl = CloudinaryService().getServiceCategoryImageUrl(
      category,
      size: (size * 2).round(),
    );
    final localFallback = CloudinaryService.getLocalAssetFallback(category);

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        cdnUrl,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            localFallback,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                _getCategoryIcon(category),
                size: size * 0.7,
                color: fallbackColor ?? AppColors.caliperCrimson,
              );
            },
          );
        },
      ),
    );
  }

  static IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('tire') || lower.contains('wheel')) {
      return Icons.album_outlined;
    }
    if (lower.contains('battery') || lower.contains('jumpstart')) {
      return Icons.battery_charging_full;
    }
    if (lower.contains('engine') || lower.contains('overheat')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('fuel')) {
      return Icons.local_gas_station_outlined;
    }
    if (lower.contains('tow')) {
      return Icons.local_shipping_outlined;
    }
    return Icons.build_outlined;
  }
}

/// Vehicle Category Illustration Widget
class VehicleIllustration extends StatelessWidget {
  final String vehicleType;
  final double size;
  final BoxFit fit;

  const VehicleIllustration({
    super.key,
    required this.vehicleType,
    this.size = 48.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final cdnUrl = CloudinaryService().getVehicleImageUrl(
      vehicleType,
      size: (size * 2).round(),
    );
    final localFallback = CloudinaryService.getLocalAssetFallback(vehicleType);

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        cdnUrl,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            localFallback,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                _getVehicleIcon(vehicleType),
                size: size * 0.7,
                color: AppColors.caliperCrimson,
              );
            },
          );
        },
      ),
    );
  }

  static IconData _getVehicleIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('motorcycle') || lower.contains('bike')) {
      return Icons.two_wheeler;
    }
    if (lower.contains('suv')) {
      return Icons.directions_car_filled;
    }
    if (lower.contains('commercial') || lower.contains('truck')) {
      return Icons.local_shipping;
    }
    return Icons.directions_car;
  }
}

/// Authentic bKash Origami Bird Vector Painter
///
/// Faithfully renders the official bKash geometric origami bird in flight
/// with exact polygonal facets. Supports both badge mode (white bird on
/// gradient container) and standalone vector mode (official duotone facets).
class BkashOrigamiBirdPainter extends CustomPainter {
  final Color primaryColor;
  final Color deepColor;
  final bool isBadgeMode;

  const BkashOrigamiBirdPainter({
    this.primaryColor = AppColors.bkashPink,
    this.deepColor = AppColors.bkashCrimson,
    this.isBadgeMode = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isBadgeMode) {
      final rect = Rect.fromLTWH(0, 0, w, h);
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, deepColor],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;

    // 1. Dominant Wing Facet (Top right wing)
    final pathWing = Path()
      ..moveTo(w * 0.44, h * 0.46)
      ..lineTo(w * 0.80, h * 0.08)
      ..lineTo(w * 0.72, h * 0.26)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white : primaryColor;
    canvas.drawPath(pathWing, fillPaint);

    // 2. Trailing/Secondary Wing Facet (Behind dominant wing)
    final pathBackWing = Path()
      ..moveTo(w * 0.44, h * 0.46)
      ..lineTo(w * 0.58, h * 0.12)
      ..lineTo(w * 0.80, h * 0.08)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white.withValues(alpha: 0.85) : deepColor;
    canvas.drawPath(pathBackWing, fillPaint);

    // 3. Head & Beak Facet (Pointing forward/right)
    final pathHead = Path()
      ..moveTo(w * 0.72, h * 0.26)
      ..lineTo(w * 0.95, h * 0.32)
      ..lineTo(w * 0.76, h * 0.42)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white : primaryColor;
    canvas.drawPath(pathHead, fillPaint);

    // 4. Central Body / Chest Facet
    final pathBody = Path()
      ..moveTo(w * 0.44, h * 0.46)
      ..lineTo(w * 0.76, h * 0.42)
      ..lineTo(w * 0.58, h * 0.68)
      ..lineTo(w * 0.38, h * 0.60)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white.withValues(alpha: 0.92) : deepColor;
    canvas.drawPath(pathBody, fillPaint);

    // 5. Tail Facet (Origami fold pointing down-left)
    final pathTail = Path()
      ..moveTo(w * 0.38, h * 0.60)
      ..lineTo(w * 0.08, h * 0.86)
      ..lineTo(w * 0.28, h * 0.54)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white.withValues(alpha: 0.80) : primaryColor;
    canvas.drawPath(pathTail, fillPaint);

    // 6. Under-tail Fold Facet (Bottom-most tail fold)
    final pathUnderTail = Path()
      ..moveTo(w * 0.38, h * 0.60)
      ..lineTo(w * 0.20, h * 0.92)
      ..lineTo(w * 0.08, h * 0.86)
      ..close();
    fillPaint.color = isBadgeMode ? Colors.white.withValues(alpha: 0.70) : deepColor;
    canvas.drawPath(pathUnderTail, fillPaint);
  }

  @override
  bool shouldRepaint(covariant BkashOrigamiBirdPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.deepColor != deepColor ||
      oldDelegate.isBadgeMode != isBadgeMode;
}

