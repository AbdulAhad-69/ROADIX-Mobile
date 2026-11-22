import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_colors.dart';

/// Reusable Brand Logo and Asset Component
///
/// Seamlessly loads official brand assets from Cloudinary CDN using optimized
/// transformations (`f_auto,q_auto`), with immediate local asset fallback
/// and high-fidelity vector painters for offline/air-gapped resilience.
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
    final key = brand.toLowerCase().trim();
    if (!showBadge) {
      return SizedBox(
        width: size,
        height: size,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: FittedBox(
            fit: fit,
            alignment: Alignment.center,
            child: SizedBox(
              width: size,
              height: size,
              child: _buildVectorPainter(key, isBadgeMode: false),
            ),
          ),
        ),
      );
    }

    final cdnUrl = CloudinaryService().getBrandLogoUrl(brand, size: (size * 2).round());
    final localFallback = CloudinaryService.getLocalAssetFallback(brand);

    return SizedBox(
      width: size,
      height: size,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: FittedBox(
          fit: fit,
          alignment: Alignment.center,
          child: SizedBox(
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
          ),
        ),
      ),
    );
  }

  Widget _buildVectorPainter(String key, {required bool isBadgeMode}) {
    if (key.contains('bkash')) {
      return CustomPaint(
        size: Size(size, size),
        painter: BkashOrigamiBirdPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('google')) {
      return CustomPaint(
        size: Size(size, size),
        painter: GoogleGLogoPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('nagad')) {
      return CustomPaint(
        size: Size(size, size),
        painter: NagadLogoPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('rocket') || key.contains('dbbl')) {
      return CustomPaint(
        size: Size(size, size),
        painter: RocketLogoPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('upay')) {
      return CustomPaint(
        size: Size(size, size),
        painter: UpayLogoPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('nexuspay') || key.contains('nexus')) {
      return CustomPaint(
        size: Size(size, size),
        painter: NexusPayLogoPainter(isBadgeMode: isBadgeMode),
      );
    } else if (key.contains('ucash')) {
      return CustomPaint(
        size: Size(size, size),
        painter: UcashLogoPainter(isBadgeMode: isBadgeMode),
      );
    }
    // Authentic fallback for any other MFS / payment string
    return CustomPaint(
      size: Size(size, size),
      painter: BkashOrigamiBirdPainter(isBadgeMode: isBadgeMode),
    );
  }

  Widget _buildVectorFallback() {
    final key = brand.toLowerCase().trim();
    return _buildVectorPainter(key, isBadgeMode: showBadge);
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

/// Authentic Google "G" Vector Painter
///
/// Faithfully renders the official multi-colored Google "G" emblem
/// with mathematically exact arcs and official brand colors:
/// - Blue:   #4285F4
/// - Green:  #34A853
/// - Yellow: #FBBC05
/// - Red:    #EA4335
class GoogleGLogoPainter extends CustomPainter {
  final bool isBadgeMode;

  const GoogleGLogoPainter({this.isBadgeMode = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isBadgeMode) {
      final rect = Rect.fromLTWH(0, 0, w, h);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRRect(rrect, bgPaint);
      final borderPaint = Paint()
        ..color = AppColors.slateBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.04);
      canvas.drawRRect(rrect, borderPaint);
    }

    final scaleFactor = (isBadgeMode ? w * 0.68 : w * 0.88) / 24.0;
    final dx = (w - 24.0 * scaleFactor) / 2.0;
    final dy = (h - 24.0 * scaleFactor) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scaleFactor, scaleFactor);

    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue segment (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.75, 12.27)
      ..cubicTo(23.75, 11.57, 23.69, 10.87, 23.56, 10.20)
      ..lineTo(12.0, 10.20)
      ..lineTo(12.0, 14.71)
      ..lineTo(18.60, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.20, 18.39)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.75, 16.27, 23.75, 12.27)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green segment (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.60, 19.20, 12.0, 19.20)
      ..cubicTo(8.88, 19.20, 6.23, 17.10, 5.28, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow segment (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.90, 12.78, 4.90, 12.0)
      ..cubicTo(4.90, 11.22, 5.04, 10.45, 5.28, 9.73)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.16, 0.0, 9.98, 0.0, 12.0)
      ..cubicTo(0.0, 14.02, 0.45, 15.84, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red segment (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.60, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.90, 8.88, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoogleGLogoPainter oldDelegate) =>
      oldDelegate.isBadgeMode != isBadgeMode;
}

/// Authentic Nagad Vector Painter
///
/// Renders the official Nagad swirling flame emblem with its vibrant
/// crimson to orange gradient (#E31C23 to #F7941D).
class NagadLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isBadgeMode;

  const NagadLogoPainter({
    this.primaryColor = const Color(0xFFE31C23),
    this.secondaryColor = const Color(0xFFF7941D),
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
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [primaryColor, secondaryColor],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    fillPaint.color = isBadgeMode ? Colors.white : primaryColor;

    final path1 = Path()
      ..moveTo(w * 0.50, h * 0.82)
      ..cubicTo(w * 0.85, h * 0.82, w * 0.92, h * 0.45, w * 0.76, h * 0.24)
      ..cubicTo(w * 0.62, h * 0.08, w * 0.38, h * 0.12, w * 0.35, h * 0.34)
      ..cubicTo(w * 0.32, h * 0.52, w * 0.55, h * 0.62, w * 0.68, h * 0.50)
      ..cubicTo(w * 0.74, h * 0.44, w * 0.72, h * 0.36, w * 0.64, h * 0.36)
      ..cubicTo(w * 0.54, h * 0.36, w * 0.48, h * 0.46, w * 0.48, h * 0.54)
      ..cubicTo(w * 0.48, h * 0.72, w * 0.35, h * 0.82, w * 0.50, h * 0.82)
      ..close();
    canvas.drawPath(path1, fillPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isBadgeMode ? Colors.white.withValues(alpha: 0.90) : secondaryColor;
    final path2 = Path()
      ..moveTo(w * 0.52, h * 0.26)
      ..cubicTo(w * 0.62, h * 0.26, w * 0.66, h * 0.36, w * 0.58, h * 0.44)
      ..cubicTo(w * 0.50, h * 0.52, w * 0.42, h * 0.46, w * 0.42, h * 0.38)
      ..cubicTo(w * 0.42, h * 0.30, w * 0.46, h * 0.26, w * 0.52, h * 0.26)
      ..close();
    canvas.drawPath(path2, innerPaint);
  }

  @override
  bool shouldRepaint(covariant NagadLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.isBadgeMode != isBadgeMode;
}

/// Authentic Dutch-Bangla Rocket Vector Painter
///
/// Renders the official DBBL Rocket emblem with its royal purple gradient
/// (#8C3494 to #591F6F), orbital trajectory swooshes, and sleek rocket ship.
class RocketLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color deepColor;
  final bool isBadgeMode;

  const RocketLogoPainter({
    this.primaryColor = const Color(0xFF8C3494),
    this.deepColor = const Color(0xFF591F6F),
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

    // 1. Orbital velocity trajectory arcs
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.045)
      ..strokeCap = StrokeCap.round
      ..color = isBadgeMode
          ? const Color(0xFFE91E63).withValues(alpha: 0.85)
          : primaryColor;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.48, h * 0.52), radius: w * 0.36),
      1.7,
      3.6,
      false,
      orbitPaint,
    );

    final innerOrbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.025)
      ..strokeCap = StrokeCap.round
      ..color = isBadgeMode ? Colors.white.withValues(alpha: 0.90) : deepColor;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.48, h * 0.52), radius: w * 0.30),
      2.0,
      3.0,
      false,
      innerOrbitPaint,
    );

    // 2. Rocket Fuselage (Tilted 45 degrees up-right)
    canvas.save();
    canvas.translate(w * 0.50, h * 0.48);
    canvas.rotate(math.pi / 4.0);

    final bodyPath = Path()
      ..moveTo(0, -h * 0.30)
      ..cubicTo(w * 0.07, -h * 0.16, w * 0.07, h * 0.10, w * 0.07, h * 0.15)
      ..lineTo(w * 0.16, h * 0.23)
      ..lineTo(w * 0.06, h * 0.19)
      ..lineTo(w * 0.04, h * 0.23)
      ..lineTo(-w * 0.04, h * 0.23)
      ..lineTo(-w * 0.06, h * 0.19)
      ..lineTo(-w * 0.16, h * 0.23)
      ..lineTo(-w * 0.07, h * 0.15)
      ..cubicTo(-w * 0.07, h * 0.10, -w * 0.07, -h * 0.16, 0, -h * 0.30)
      ..close();

    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isBadgeMode ? Colors.white : primaryColor;
    canvas.drawPath(bodyPath, bodyPaint);

    final windowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isBadgeMode ? primaryColor : Colors.white;
    canvas.drawCircle(Offset(0, -h * 0.06), w * 0.038, windowPaint);

    final flamePath = Path()
      ..moveTo(-w * 0.035, h * 0.23)
      ..lineTo(0, h * 0.35)
      ..lineTo(w * 0.035, h * 0.23)
      ..close();
    final flamePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFC107);
    canvas.drawPath(flamePath, flamePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RocketLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.deepColor != deepColor ||
      oldDelegate.isBadgeMode != isBadgeMode;
}

/// Authentic UCB Upay Vector Painter
///
/// Renders the official Upay blue badge (#004481) with its iconic
/// golden amber "u" smile curve (#FFC800) and energetic white arc.
class UpayLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color yellowColor;
  final bool isBadgeMode;

  const UpayLogoPainter({
    this.primaryColor = const Color(0xFF004481),
    this.yellowColor = const Color(0xFFFFC800),
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
          colors: [primaryColor, const Color(0xFF002D62)],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    }

    // 1. Upay golden smile / "u" curve
    final uPath = Path()
      ..moveTo(w * 0.30, h * 0.34)
      ..lineTo(w * 0.30, h * 0.52)
      ..arcToPoint(
        Offset(w * 0.70, h * 0.52),
        radius: Radius.circular(w * 0.20),
        clockwise: false,
      )
      ..lineTo(w * 0.70, h * 0.34);

    final uPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, w * 0.11)
      ..strokeCap = StrokeCap.round
      ..color = yellowColor;
    canvas.drawPath(uPath, uPaint);

    // 2. Dynamic top swoosh
    final swooshPath = Path()
      ..moveTo(w * 0.24, h * 0.34)
      ..cubicTo(w * 0.36, h * 0.18, w * 0.64, h * 0.18, w * 0.78, h * 0.30);
    final swooshPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.045)
      ..strokeCap = StrokeCap.round
      ..color = isBadgeMode ? Colors.white.withValues(alpha: 0.90) : primaryColor;
    canvas.drawPath(swooshPath, swooshPaint);

    // 3. Yellow accent dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = yellowColor;
    canvas.drawCircle(Offset(w * 0.70, h * 0.24), w * 0.045, dotPaint);
  }

  @override
  bool shouldRepaint(covariant UpayLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.yellowColor != yellowColor ||
      oldDelegate.isBadgeMode != isBadgeMode;
}

/// Authentic Dutch-Bangla NexusPay Vector Painter
///
/// Renders the official NexusPay emblem in Dutch-Bangla Navy Blue (#005A9C),
/// stylized white payment card container, and dynamic DBBL orange (#F58220) wings.
class NexusPayLogoPainter extends CustomPainter {
  final Color dbblBlue;
  final Color dbblOrange;
  final bool isBadgeMode;

  const NexusPayLogoPainter({
    this.dbblBlue = const Color(0xFF005A9C),
    this.dbblOrange = const Color(0xFFF58220),
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
          colors: [dbblBlue, const Color(0xFF003865)],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    }

    // 1. Stylized Payment Card Shape
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.52),
        width: w * 0.68,
        height: h * 0.46,
      ),
      Radius.circular(w * 0.08),
    );
    final cardPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isBadgeMode ? Colors.white : const Color(0xFFF8FAFC);
    canvas.drawRRect(cardRect, cardPaint);

    // 2. Upper DBBL Wing (Orange #F58220)
    final topWing = Path()
      ..moveTo(w * 0.32, h * 0.58)
      ..lineTo(w * 0.44, h * 0.40)
      ..lineTo(w * 0.68, h * 0.40)
      ..lineTo(w * 0.56, h * 0.50)
      ..close();
    final orangePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dbblOrange;
    canvas.drawPath(topWing, orangePaint);

    // 3. Lower DBBL Wing (Blue #005A9C)
    final botWing = Path()
      ..moveTo(w * 0.38, h * 0.62)
      ..lineTo(w * 0.52, h * 0.52)
      ..lineTo(w * 0.74, h * 0.52)
      ..lineTo(w * 0.60, h * 0.62)
      ..close();
    final bluePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dbblBlue;
    canvas.drawPath(botWing, bluePaint);

    // 4. Contactless waves indicator in top right
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.025)
      ..strokeCap = StrokeCap.round
      ..color = dbblBlue.withValues(alpha: 0.80);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.70, h * 0.42), radius: w * 0.06),
      3.2,
      1.2,
      false,
      wavePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.70, h * 0.42), radius: w * 0.09),
      3.2,
      1.2,
      false,
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant NexusPayLogoPainter oldDelegate) =>
      oldDelegate.dbblBlue != dbblBlue ||
      oldDelegate.dbblOrange != dbblOrange ||
      oldDelegate.isBadgeMode != isBadgeMode;
}

/// Authentic Ucash Vector Painter
///
/// Renders the official Ucash dual-curve stylized emblem in Crimson Red (#ED1C24)
/// and Emerald Green (#009639) with central digital currency coin accent.
class UcashLogoPainter extends CustomPainter {
  final Color redColor;
  final Color greenColor;
  final bool isBadgeMode;

  const UcashLogoPainter({
    this.redColor = const Color(0xFFED1C24),
    this.greenColor = const Color(0xFF009639),
    this.isBadgeMode = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isBadgeMode) {
      final rect = Rect.fromLTWH(0, 0, w, h);
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    }

    // 1. Left Red Branch of "U"
    final leftBranch = Path()
      ..moveTo(w * 0.30, h * 0.28)
      ..lineTo(w * 0.30, h * 0.52)
      ..arcToPoint(
        Offset(w * 0.50, h * 0.72),
        radius: Radius.circular(w * 0.20),
        clockwise: false,
      );
    final redPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, w * 0.09)
      ..strokeCap = StrokeCap.round
      ..color = redColor;
    canvas.drawPath(leftBranch, redPaint);

    // 2. Right Green Branch of "U"
    final rightBranch = Path()
      ..moveTo(w * 0.50, h * 0.72)
      ..arcToPoint(
        Offset(w * 0.70, h * 0.52),
        radius: Radius.circular(w * 0.20),
        clockwise: false,
      )
      ..lineTo(w * 0.70, h * 0.28);
    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, w * 0.09)
      ..strokeCap = StrokeCap.round
      ..color = greenColor;
    canvas.drawPath(rightBranch, greenPaint);

    // 3. Central Digital Coin Accent (#FFD700)
    final coinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(w * 0.50, h * 0.44), w * 0.065, coinPaint);

    final innerCoinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.50, h * 0.44), w * 0.035, innerCoinPaint);
  }

  @override
  bool shouldRepaint(covariant UcashLogoPainter oldDelegate) =>
      oldDelegate.redColor != redColor ||
      oldDelegate.greenColor != greenColor ||
      oldDelegate.isBadgeMode != isBadgeMode;
}
