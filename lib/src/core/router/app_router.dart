import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../../services/demo_session.dart';
import '../../features/emergency_triage/application/triage_controller.dart';

/// Centralized route paths for ROADIX.
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

  static const Set<String> publicPaths = {
    root,
    splash,
    login,
    otp,
    sos,
  };
}

/// Pure, testable route guard calculator so navigation policy is verified cleanly.
String? computeAuthRedirect({
  required String currentPath,
  required bool isSignedIn,
  required String? userRole,
}) {
  if (currentPath == AppRoutes.root) return AppRoutes.splash;
  if (!isSignedIn) {
    return AppRoutes.publicPaths.contains(currentPath) ? null : AppRoutes.login;
  }
  final targetHome =
      userRole == 'mechanic' ? AppRoutes.mechanic : AppRoutes.home;
  if (currentPath == AppRoutes.login) return targetHome;
  if (currentPath == AppRoutes.mechanic && userRole != 'mechanic') {
    return AppRoutes.home;
  }
  return null;
}

/// Navigates to a root destination cleanly under both GoRouter (`RoadixApp`)
/// and isolated `MaterialApp` widget tests.
void navigateRoot(
  BuildContext context, {
  required String route,
  required Widget fallbackWidget,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(route);
    return;
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => fallbackWidget),
    (_) => false,
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  String? _cachedRole;
  String? _cachedUserId;

  _RouterRefreshNotifier() {
    DemoSession.notifier.addListener(notifyListeners);
    try {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final uid = data.session?.user.id;
        if (uid != _cachedUserId) {
          _cachedUserId = uid;
          _cachedRole =
              data.session?.user.userMetadata?['role']?.toString();
          if (uid != null) _refreshProfileRole(uid);
        }
        notifyListeners();
      });
    } catch (_) {}
  }

  String? get currentRole {
    if (DemoSession.isActive) return DemoSession.role;
    final user = _safeCurrentUser();
    if (user == null) return null;
    if (_cachedUserId == user.id && _cachedRole != null) return _cachedRole;
    return user.userMetadata?['role']?.toString();
  }

  User? _safeCurrentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshProfileRole(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      final role = res?['role']?.toString();
      if (role != null && role != _cachedRole) {
        _cachedRole = role;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    DemoSession.notifier.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Global GoRouter provider with auth & role guards.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      User? user;
      try {
        user = Supabase.instance.client.auth.currentUser;
      } catch (_) {}
      final isSignedIn = user != null || DemoSession.isActive;
      return computeAuthRedirect(
        currentPath: state.uri.path,
        isSignedIn: isSignedIn,
        userRole: refreshNotifier.currentRole,
      );
    },
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
          final triage = ref.read(triageControllerProvider);
          final fault = (state.extra as String?) ??
              state.uri.queryParameters['fault'] ??
              triage.selectedFault ??
              'General Breakdown';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              triage.latitude;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              triage.longitude;
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
          final triage = ref.read(triageControllerProvider);
          final fault = (state.extra as String?) ??
              state.uri.queryParameters['fault'] ??
              triage.selectedFault ??
              'General Breakdown';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              triage.latitude;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              triage.longitude;
          final address = state.uri.queryParameters['address'] ??
              (triage.pickupAddress.isNotEmpty
                  ? triage.pickupAddress
                  : 'Dhaka Region • Roadside Position');
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
          final triage = ref.read(triageControllerProvider);
          final fault = state.uri.queryParameters['fault'] ??
              triage.selectedFault ??
              'General Breakdown';
          final rawVehicle = state.uri.queryParameters['vehicle'] ??
              triage.vehicleType ??
              'Passenger Car';
          final vehicle = VehicleSelectScreen.mapUiCategoryToSrs(rawVehicle);
          final plate = state.uri.queryParameters['plate'] ??
              triage.licensePlate ??
              'DHAKA-METRO';
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              triage.latitude;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              triage.longitude;
          final address = state.uri.queryParameters['address'] ??
              (triage.pickupAddress.isNotEmpty
                  ? triage.pickupAddress
                  : 'Dhaka Region • Roadside Position');
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
          final triage = ref.read(triageControllerProvider);
          final fault = state.uri.queryParameters['fault'] ??
              triage.selectedFault ??
              'General Breakdown';
          final rawVehicle = state.uri.queryParameters['vehicle'] ??
              triage.vehicleType ??
              'Passenger Car';
          final vehicle = VehicleSelectScreen.mapUiCategoryToSrs(rawVehicle);
          final plate = state.uri.queryParameters['plate'] ??
              triage.licensePlate ??
              'DHAKA-METRO';
          final isHighPriority = state.uri.queryParameters['priority'] != null
              ? state.uri.queryParameters['priority'] == 'true'
              : triage.isHighPriority;
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
              triage.latitude;
          final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
              triage.longitude;
          final address = state.uri.queryParameters['address'] ??
              (triage.pickupAddress.isNotEmpty
                  ? triage.pickupAddress
                  : 'Dhaka Region • Roadside Position');
          final notes = state.uri.queryParameters['notes'] ?? triage.notes;
          final requestId =
              state.uri.queryParameters['requestId'] ?? triage.activeRequestId;
          return DispatchScreen(
            selectedFault: fault,
            vehicleType: vehicle,
            licensePlate: plate,
            symptoms: triage.symptoms,
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
