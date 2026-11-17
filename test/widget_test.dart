import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/src/core/router/app_router.dart';

void main() {
  group('AppRouter Route Definition Smoke Tests', () {
    test('route path constants are defined and unique', () {
      final routes = [
        AppRoutes.root,
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.otp,
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
      ];
      final uniqueRoutes = routes.toSet();
      expect(uniqueRoutes.length, equals(routes.length));
    });
  });
}
