# Phase 03 — Flutter Foundation and Architecture Migration

**Phase Status:** COMPLETED  
**Completion Date:** 2026-11-17  
**Approved Baseline:** Phase 00, Phase 01, Phase 02  

---

## 1. Objective

Establish the core application foundation for ROADIX adhering to the approved feature-first layered architecture (`presentation → application → domain → data`), Riverpod state management, GoRouter declarative navigation, compile-time environment configuration, and PostGIS/Supabase provider integration — without breaking existing functional screens or incurring paid third-party costs.

---

## 2. Completed Work

### 2.1 Dependency Refactoring & Ghost Package Pruning
- **Removed 7 unused / ghost packages** from `pubspec.yaml`:
  - `flutter_bloc`
  - `get_it`
  - `equatable`
  - `latlong2`
  - `drift`
  - `sqlite3_flutter_libs`
  - `dio`
- **Removed 2 unused code generators**:
  - `drift_dev`
  - `build_runner`
- **Added approved architectural packages**:
  - `flutter_riverpod: ^2.6.1` & `riverpod: ^2.6.1`: State management across application and domain layers.
  - `go_router: ^14.8.1`: Declarative URL routing and role-based redirect protection.
  - `flutter_secure_storage: ^11.2.0`: Keychain / Keystore secure token storage compatible with `win32 ^6.0.0` and `geolocator ^14.0.3`.
  - `test: ^1.25.8` (dev): Pure Dart test runner.
- **Retained Zero-Budget Core Libraries**:
  - `maplibre_gl: ^0.27.1` (OpenFreeMap vector tiles).
  - `geolocator: ^14.0.3` (GPS device location).
  - `supabase_flutter: ^2.8.4` (PostgreSQL / Auth / Realtime client).

### 2.2 iOS Permission Configuration
- Added missing usage description keys to `ios/Runner/Info.plist`:
  - `NSLocationWhenInUseUsageDescription`: "ROADIX needs your location to dispatch nearby mechanics to your exact breakdown location."
  - `NSLocationAlwaysAndWhenInUseUsageDescription`: "ROADIX needs your location to track mechanic arrival and roadside emergency progress."

### 2.3 Environment Configuration (`lib/src/core/config/app_config.dart`)
- Implemented `AppConfig` reading `--dart-define` compile-time environment variables with safe development fallbacks:
  - `ROADIX_SUPABASE_URL`
  - `ROADIX_SUPABASE_ANON_KEY`
  - `ROADIX_MAP_STYLE_URL` (`https://tiles.openfreemap.org/styles/liberty`)
  - Operational constants: `initialSearchRadiusKm = 5.0`, `expansionRadiusKm = 2.5`, `dispatchTimeoutSeconds = 45`, `emergencyHotline = '999'`.

### 2.4 Functional Error Handling (`lib/src/core/errors/`)
- `Failure` sealed hierarchy: `NetworkFailure`, `AuthFailure`, `PermissionFailure`, `TriageFailure`, `ServerFailure`, `CacheFailure`.
- `Result<T>` sealed monad: `Success<T>` and `Error<T>` with pattern matching (`when`), functor mapping (`map`), and monadic binding (`flatMap`).

### 2.5 Supabase Riverpod Providers (`lib/src/core/network/supabase_providers.dart`)
- `supabaseClientProvider`: Injected singleton client.
- `supabaseAuthProvider`: GoTrue authentication instance.
- `authStateChangesProvider`: Reactive auth stream provider.
- `currentUserProvider` & `currentSessionProvider`: Auto-updating auth state providers.
- `isAuthenticatedProvider`: Boolean convenience provider.

### 2.6 Emergency Triage Foundation (`lib/src/features/emergency_triage/`)
- `TriageState`: Immutable state holding emergency fault type, GPS coordinates (`latitude`, `longitude`), textual pickup address, vehicle type, license plate, symptoms, diagnostic notes, hazard flags, and active request ID.
- `TriageController`: Riverpod `StateNotifier` managing wizard step transitions and fixing Critical Audit Bug #1 (dropped GPS coordinates) and Bug #2 (dropped diagnostic notes).

### 2.7 Declarative Navigation (`lib/src/core/router/app_router.dart`)
- Configured `GoRouter` with typed constants (`AppRoutes`):
  - `/` (redirects to `/splash`)
  - `/splash` -> `SplashScreen`
  - `/login` -> `LoginScreen`
  - `/otp` -> `OtpVerificationScreen`
  - `/profile-setup` -> `ProfileSetupScreen`
  - `/home` -> `EmergencyHomeScreen`
  - `/location-permission` -> `LocationPermissionScreen`
  - `/location-confirm` -> `LocationConfirmScreen`
  - `/vehicle-select` -> `VehicleSelectScreen`
  - `/fault-details` -> `FaultDetailsScreen`
  - `/dispatch` -> `DispatchScreen`
  - `/activity` -> `ActivityScreen`
  - `/profile` -> `ProfileScreen`
  - `/sos` -> `SosScreen`

### 2.8 Application Entrypoint Migration
- `lib/src/app.dart`: Configured `RoadixApp` as a `ConsumerWidget` with `MaterialApp.router` using `AppColors.caliperCrimson` and `AppColors.porcelainBg`.
- `lib/main.dart`: Initialized `AppConfig`, configured `Supabase.initialize`, and wrapped application root with `ProviderScope(child: RoadixApp())`. Preserved `supabase` top-level getter for backward compatibility.

---

## 3. Verification & Test Results

1. **Unit Test Execution:**
   - Command: `dart test test/unit/foundation_test.dart`
   - Result: **All 6 tests passed** (0 failures, 100% success).
   - Covered: `AppConfig`, `Failure`, `Result<T>`, `TriageState`, and `TriageController`.
2. **Static Analysis:**
   - Command: `dart analyze`
   - Result: **0 errors, 0 warnings in all new architecture files (`lib/src/`)**.
3. **Zero-Budget Compliance:**
   - Maintained `maplibre_gl` and OpenFreeMap tile endpoints.
   - Zero paid SDKs introduced.

---

## 4. Next Phase

- **Phase 04:** Database & Backend Implementation (Supabase Migrations, PostGIS Spatial Extension, RLS Security Policies, Stored Procedures, and Seed Data).
