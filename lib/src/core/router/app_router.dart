import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../screens/activity_screen.dart';
import '../../../screens/dispatch_screen.dart';
import '../../../screens/emergency_home_screen.dart';
import '../../../screens/fault_details_screen.dart';
import '../../../screens/location_confirm_screen.dart';
import '../../../screens/location_permission_screen.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/mechanic_home_screen.dart';
import '../../../screens/otp_verification_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/profile_setup_screen.dart';
import '../../../screens/sos_screen.dart';
import '../../../screens/splash_screen.dart';
import '../../../screens/vehicle_select_screen.dart';

/// Centralized route paths for ROADIX
abstract class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String locationPermission = '/location-permission';
  static const String locationConfirm = '/location-confirm';
  static const String vehicleSelect = '/vehicle-select';
  static const String faultDetails = '/fault-details';
  static const String dispatch = '/dispatch';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String sos = '/sos';
  static const String mechanic = '/mechanic';
}

/// Global GoRouter provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (_, _) => AppRoutes.splash,
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = (state.extra as String?) ??
              state.uri.queryParameters['phone'] ??
              '';
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) {
          final phone = (state.extra as String?) ??
              state.uri.queryParameters['phone'] ??
              '';
          return ProfileSetupScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const EmergencyHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationPermission,
        builder: (context, state) {
          final fault = (state.extra as String?) ??
              state.uri.queryParameters['fault'] ??
              'General Breakdown';
          return LocationPermissionScreen(selectedFault: fault);
        },
      ),
      GoRoute(
        path: AppRoutes.locationConfirm,
        builder: (context, state) {
          final fault = (state.extra as String?) ??
              state.uri.queryParameters['fault'] ??
              'General Breakdown';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              23.8759;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              90.3795;
          return LocationConfirmScreen(
            selectedFault: fault,
            initialLat: lat,
            initialLng: lng,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.vehicleSelect,
        builder: (context, state) {
          final fault = (state.extra as String?) ??
              state.uri.queryParameters['fault'] ??
              'General Breakdown';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              23.8759;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              90.3795;
          final address = state.uri.queryParameters['address'] ??
              'Dhaka Region • Roadside Position';
          return VehicleSelectScreen(
            selectedFault: fault,
            breakdownLat: lat,
            breakdownLng: lng,
            breakdownAddress: address,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.faultDetails,
        builder: (context, state) {
          final fault = state.uri.queryParameters['fault'] ?? 'General';
          final rawVehicle = state.uri.queryParameters['vehicle'] ?? 'Passenger Car';
          final vehicle = VehicleSelectScreen.mapUiCategoryToSrs(rawVehicle);
          final plate = state.uri.queryParameters['plate'] ?? 'DHAKA-METRO';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              23.8759;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              90.3795;
          final address = state.uri.queryParameters['address'] ??
              'Dhaka Region • Roadside Position';
          return FaultDetailsScreen(
            selectedFault: fault,
            vehicleType: vehicle,
            licensePlate: plate,
            breakdownLat: lat,
            breakdownLng: lng,
            breakdownAddress: address,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.dispatch,
        builder: (context, state) {
          final fault = state.uri.queryParameters['fault'] ?? 'General';
          final rawVehicle = state.uri.queryParameters['vehicle'] ?? 'Passenger Car';
          final vehicle = VehicleSelectScreen.mapUiCategoryToSrs(rawVehicle);
          final plate = state.uri.queryParameters['plate'] ?? 'DHAKA-METRO';
          final isHighPriority =
              state.uri.queryParameters['priority'] == 'true';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              23.8759;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              90.3795;
          final address = state.uri.queryParameters['address'] ??
              'Dhaka Region • Roadside Position';
          final notes = state.uri.queryParameters['notes'] ?? '';
          final requestId = state.uri.queryParameters['requestId'];
          return DispatchScreen(
            selectedFault: fault,
            vehicleType: vehicle,
            licensePlate: plate,
            symptoms: const [],
            isHighPriority: isHighPriority,
            breakdownLat: lat,
            breakdownLng: lng,
            breakdownAddress: address,
            diagnosticNotes: notes,
            existingRequestId: requestId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.sos,
        builder: (context, state) => const SosScreen(),
      ),
      GoRoute(
        path: AppRoutes.mechanic,
        builder: (context, state) => const MechanicHomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri.path}'),
      ),
    ),
  );
});
