import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/src/core/router/app_router.dart';
import 'package:roadix_mobile/theme/app_colors.dart';

void main() {
  group('AppRouter Route Definition Smoke Tests', () {
    test('route path constants are defined and unique', () {
      final routes = [
        AppRoutes.root,
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.paymentCallback,
        AppRoutes.profileSetup,
        AppRoutes.home,
        AppRoutes.locationPermission,
        AppRoutes.locationConfirm,
        AppRoutes.vehicleSelect,
        AppRoutes.faultDetails,
        AppRoutes.dispatch,
        AppRoutes.activity,
        AppRoutes.profile,
        AppRoutes.sos,
        AppRoutes.mechanic,
      ];
      final uniqueRoutes = routes.toSet();
      expect(uniqueRoutes.length, equals(routes.length));
      expect(routes.contains('/mechanic'), isTrue);
    });
  });

  group('Showroom Porcelain Automotive Theme Verification Tests', () {
    test('AppColors palette adheres strictly to specification tokens', () {
      expect(AppColors.porcelainBg, equals(const Color(0xFFF8FAFC)));
      expect(AppColors.chassisText, equals(const Color(0xFF0F172A)));
      expect(AppColors.caliperCrimson, equals(const Color(0xFFDC2626)));
      expect(AppColors.emeraldGps, equals(const Color(0xFF10B981)));
      expect(AppColors.cardWhite, equals(const Color(0xFFFFFFFF)));
      expect(AppColors.slateBorder, equals(const Color(0xFFE2E8F0)));
    });

    test('VehicleSelectScreen default classification correctly maps SRS types', () {
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan / Hatch'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Motorcycle'), equals('Motorcycle'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Commercial'), equals('Light Commercial'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Unknown'), equals('Passenger Car'));
    });
  });
}

