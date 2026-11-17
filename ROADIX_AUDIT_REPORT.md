# ROADIX — Comprehensive Technical & Architectural Audit Report

**Date of Audit:** November 17, 2026  
**Auditor Role:** Senior Software Architect & Technical Auditor  
**Repository Audited:** `c:\Users\aahad\ROADIX-Mobile`  
**Report File:** `ROADIX_AUDIT_REPORT.md`  

---

## 1. Executive Summary

ROADIX is envisioned as a real-time, location-aware roadside assistance and emergency mechanic dispatch platform tailored for Bangladesh (Dhaka metropolitan area initial focus). The complete platform vision encompasses a Flutter mobile application for motorists, a web application, an administrative backend, mechanic/provider management, real-time dispatching, GPS telemetry, and transparent quoting.

### Current Maturity & Readiness Assessment
The current codebase in this repository is strictly an **early-stage UI prototype / Proof of Concept (PoC)** of the Flutter mobile client. It exhibits a polished visual design following a custom design system ("Showroom Porcelain" with "Caliper Crimson" accents), but **its operational core is almost entirely simulated**:
- **0% Real Dispatching:** The 4-step emergency triage wizard is hardcoded. It uses a 3-second UI `Timer` to fake finding a technician, hardcodes a technician ("Md. Rafiqul Islam"), and fabricates an invoice.
- **Critical Data-Flow Severing:** Coordinates gathered via `geolocator` and MapLibre in Step 1 are **completely discarded** when navigating to Step 2. Triage notes entered in Step 3 are **discarded** when navigating to Step 4. No dispatch or request record is ever transmitted to a backend.
- **Shared Static Identity:** While CRUD operations for user profiles, vehicles, and emergency contacts are connected to Supabase, they all target a **single hardcoded static UUID** (`a0000000-0000-0000-0000-000000000001`). There is no user isolation or dynamic session binding.
- **Architectural Void & Dependency Ghosting:** The project declares heavy architectural libraries (`flutter_bloc`, `get_it`, `drift`, `dio`, `equatable`), but **none of them are imported or used anywhere**. The entire application relies on ad-hoc `setState()` in monolithic UI files without domain models or typed entities.
- **Platform Crash Risk on iOS:** Location permissions (`NSLocationWhenInUseUsageDescription`) are completely missing from `ios/Runner/Info.plist`, guaranteeing immediate runtime crashes on Apple devices.

**Overall Status: PROTOTYPE / NON-PRODUCTION READY**. The frontend provides a solid visual wireframe, but requires architectural restructuring and actual service-layer implementation before any production deployment.

---

## 2. Project Structure and Technology Stack

### 2.1 File & Directory Inventory
```text
c:\Users\aahad\ROADIX-Mobile/
├── android/                         # Android native project (Kotlin DSL gradle)
├── ios/                             # iOS native project (Missing CocoaPods Podfile)
├── assets/images/logo.png           # Brand asset
├── lib/                             # Application source code (26 Dart files)
│   ├── main.dart                    # App entrypoint & Supabase initialization
│   ├── theme/
│   │   └── app_colors.dart          # Palette tokens (Showroom Porcelain / Caliper Crimson)
│   ├── services/
│   │   └── supabase_service.dart    # PostgREST database CRUD client (Profile, Garage, Contacts, Wallets)
│   ├── screens/                     # 13 Screen widgets (Ad-hoc UI + local state)
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── otp_verification_screen.dart
│   │   ├── profile_setup_screen.dart
│   │   ├── location_permission_screen.dart
│   │   ├── location_confirm_screen.dart
│   │   ├── vehicle_select_screen.dart
│   │   ├── fault_details_screen.dart
│   │   ├── dispatch_screen.dart
│   │   ├── emergency_home_screen.dart
│   │   ├── sos_screen.dart
│   │   ├── activity_screen.dart
│   │   └── profile_screen.dart
│   └── widgets/                     # 6 Modal bottom sheets
│       ├── contact_editor_sheet.dart
│       ├── edit_profile_sheet.dart
│       ├── notifications_bottom_sheet.dart
│       ├── search_bottom_sheet.dart
│       ├── vehicle_editor_sheet.dart
│       └── wallet_editor_sheet.dart
├── test/
│   └── widget_test.dart             # Default boilerplate counter test (Irrelevant / Unused)
├── pubspec.yaml                     # Project manifest and dependencies
├── pubspec.lock                     # Locked dependency tree
├── analysis_options.yaml            # Standard Flutter lints
└── README.md                        # Default template README
```

### 2.2 Dependency Audit: Ghost & Unused Packages

An inspection of `pubspec.yaml` versus all `.dart` imports across `lib/` revealed massive dependency bloat. The project includes heavy architecture packages that are completely unused:

| Declared Package | Declared Version | Status in Code | Usage Evidence |
| :--- | :--- | :--- | :--- |
| `supabase_flutter` | `^2.8.4` | **USED** | Imported in `main.dart` and `supabase_service.dart`. |
| `maplibre_gl` | `^0.27.1` | **USED** | Imported in `location_confirm_screen.dart` for vector tiles. |
| `geolocator` | `^14.0.3` | **USED** | Imported in `location_permission_screen.dart` for GPS. |
| `cupertino_icons` | `^1.0.8` | **USED** | Icon pack. |
| `flutter_bloc` | `^9.1.1` | **UNUSED (GHOST)** | **0 imports**. No Blocs, Cubits, or Providers exist. |
| `get_it` | `^9.3.0` | **UNUSED (GHOST)** | **0 imports**. No dependency injection container configured. |
| `equatable` | `^3.0.0` | **UNUSED (GHOST)** | **0 imports**. No value-equality models or states exist. |
| `drift` | `^2.35.0` | **UNUSED (GHOST)** | **0 imports**. No offline SQLite database or tables defined. |
| `sqlite3_flutter_libs`| `^0.6.0+eol` | **UNUSED (GHOST)** | **0 imports**. Bundled native SQLite binaries sitting unused. |
| `path_provider` | `^2.1.6` | **UNUSED (GHOST)** | **0 imports**. No file system access or cache storage logic. |
| `dio` | `^5.11.1` | **UNUSED (GHOST)** | **0 imports**. No HTTP REST client configured. |
| `latlong2` | `^0.10.1` | **UNUSED (GHOST)** | **0 imports**. MapLibre uses its own internal `LatLng`. |
| `build_runner` (dev) | `^2.16.1` | **UNUSED** | No code generators executed or configured. |
| `drift_dev` (dev) | `^2.35.0` | **UNUSED** | No Drift code generator configured. |

---

## 3. Existing Architecture

### 3.1 Architectural Pattern
The existing codebase implements a **Zero-Architecture / Monolithic View pattern**:
- **No Layer Separation:** Business logic, navigation, animation controllers, mock data generation, and PostgREST queries are co-located directly inside Widget `State` classes.
- **Absence of Domain Entities / Models:** There is not a single domain model class (e.g. `User`, `Vehicle`, `Dispatch`, `Mechanic`, `Quote`) in the entire project. All data is handled as raw `Map<String, dynamic>` dictionaries with string key indexing, providing zero type safety and high vulnerability to typos and null-pointer exceptions.
- **Monolithic God Widgets:** `EmergencyHomeScreen` is 867 lines; `ProfileScreen` is 721 lines; `SosScreen` is 632 lines; `VehicleSelectScreen` is 532 lines.

### 3.2 State Management
- **Pattern:** `StatefulWidget` with local `setState()`.
- **Global State:** None. Top-level state (e.g. active user, active dispatch status, location coordinates) does not exist across screen boundaries.
- **Cross-Screen Communication:** Data is passed forward via constructors in `MaterialPageRoute`. Because there is no state container, when intermediate screens drop parameters (such as location and notes), the data is permanently lost.

### 3.3 Routing and Navigation
- **Pattern:** Direct imperative navigation via `Navigator.push(context, MaterialPageRoute(...))`.
- **Issues:** No named routes, no deep-linking, no declarative router (e.g., `go_router`). Back-stack management is fragile and inconsistent (e.g. mixing `pushReplacement`, `pushAndRemoveUntil`, and standard `push`).

---

## 4. Feature Implementation Status

Each platform capability is classified into one of the designated status labels:

| Feature / Module | Status | File Reference | Technical Finding & Evidence |
| :--- | :--- | :--- | :--- |
| **Phone Login & PIN Pad** | **SIMULATED** | [`lib/screens/login_screen.dart#L46-L54`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/login_screen.dart#L46-L54) | Custom keypad collects digits, but `_proceedToOtp` does not invoke `supabase.auth.signInWithOtp()`. Features a "Skip to SOS" bypass button that allows entering the app unauthenticated. |
| **SMS OTP Verification** | **SIMULATED** | [`lib/screens/otp_verification_screen.dart#L59-L67`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/otp_verification_screen.dart#L59-L67) | Any 6 digits pass verification (`if (_enteredOtp.length == 6)`). No verification code is verified with Supabase Auth or SMS gateway. |
| **Profile Onboarding** | **SIMULATED** | [`lib/screens/profile_setup_screen.dart#L36-L41`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/profile_setup_screen.dart#L36-L41) | UI collects motorist name, vehicle, and fuel type, but `_finishSetup` navigates straight to `EmergencyHomeScreen` without saving anything to Supabase. |
| **GPS Location Permission** | **IMPLEMENTED** | [`lib/screens/location_permission_screen.dart#L18-L83`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/location_permission_screen.dart#L18-L83) | Genuinely requests device location permission using `geolocator` and fetches live GPS position; has graceful fallback to Dhaka center if timed out. |
| **Map Location Confirmation** | **PARTIALLY IMPLEMENTED** | [`lib/screens/location_confirm_screen.dart#L25-L35`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/location_confirm_screen.dart#L25-L35) | Renders OpenFreeMap vector tiles on MapLibre GL. **Broken Data Flow:** Confirmation button drops `initialLat`/`initialLng` when routing to `VehicleSelectScreen` (Line 405-412). |
| **Vehicle Selection (Triage)** | **SIMULATED** | [`lib/screens/vehicle_select_screen.dart#L22-L46`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/vehicle_select_screen.dart#L22-L46) | Hardcoded vehicle list ('Toyota Allion', 'Yamaha FZS'). Does not fetch vehicles from `SupabaseService`. |
| **Fault Diagnostic Questionnaire**| **PARTIALLY IMPLEMENTED** | [`lib/screens/fault_details_screen.dart#L27-L71`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/fault_details_screen.dart#L27-L71) | Client-side symptom generator responds to fault category. Drops user notes (`_notesController.text`) upon submission. |
| **Mechanic Discovery & Radar** | **SIMULATED** | [`lib/screens/dispatch_screen.dart#L41-L47`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/dispatch_screen.dart#L41-L47) | Plays a 3-second animated sonar circle, then hardcodes match with "Md. Rafiqul Islam". No database queries or spatial matching. |
| **Service Quotation & Approval** | **SIMULATED** | [`lib/screens/dispatch_screen.dart#L311-L325`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/dispatch_screen.dart#L311-L325) | Hardcodes static estimate (৳ 1,250). "Approve Quote" only changes local enum `_phase` and shows a SnackBar. No transaction or backend record. |
| **Live Mechanic Tracking** | **SIMULATED** | [`lib/screens/dispatch_screen.dart#L360-L450`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/dispatch_screen.dart#L360-L450) | Displays mock ETA (9 mins) and static status bar. No WebSockets, Supabase Realtime, or GPS streaming. |
| **Emergency SOS (999)** | **SIMULATED** | [`lib/screens/sos_screen.dart#L34-L45`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/sos_screen.dart#L34-L45) | 5-second countdown timer. At 0 seconds, displays a SnackBar. Does not launch the phone dialer (`url_launcher` missing) and does not dispatch emergency contacts. |
| **Activity & Rescue History** | **SIMULATED** | [`lib/screens/activity_screen.dart#L158-L195`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/activity_screen.dart#L158-L195) | Static hardcoded list of 3 past rescues (`RDX-2026-9041`, etc.) and hardcoded invoice modal. No database queries. |
| **Facility Search** | **SIMULATED** | [`lib/widgets/search_bottom_sheet.dart#L25-L76`](file:///c:/Users/aahad/ROADIX-Mobile/lib/widgets/search_bottom_sheet.dart#L25-L76) | In-memory filtering of 5 hardcoded Dhaka facilities. No backend search API. |
| **Safety & Weather Alerts** | **SIMULATED** | [`lib/widgets/notifications_bottom_sheet.dart#L14-L55`](file:///c:/Users/aahad/ROADIX-Mobile/lib/widgets/notifications_bottom_sheet.dart#L14-L55) | Static list of mock waterlogging/hazard alerts. Mark-as-read is ephemeral. |
| **User Profile Management** | **PARTIALLY IMPLEMENTED** | [`lib/screens/profile_screen.dart#L40-L44`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/profile_screen.dart#L40-L44) | Reads/writes to Supabase `profiles` table, but locked to hardcoded `defaultProfileId`. |
| **Digital Garage CRUD** | **PARTIALLY IMPLEMENTED** | [`lib/services/supabase_service.dart#L47-L89`](file:///c:/Users/aahad/ROADIX-Mobile/lib/services/supabase_service.dart#L47-L89) | Add, edit, delete vehicles persists to Supabase `vehicles` table, but locked to `defaultProfileId`. |
| **Emergency Contacts CRUD** | **PARTIALLY IMPLEMENTED** | [`lib/services/supabase_service.dart#L95-L132`](file:///c:/Users/aahad/ROADIX-Mobile/lib/services/supabase_service.dart#L95-L132) | Add, edit, delete emergency contacts persists to Supabase `emergency_contacts` table, but locked to `defaultProfileId`. |
| **MFS Wallet Management** | **PARTIALLY IMPLEMENTED** | [`lib/screens/profile_screen.dart#L188-L208`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/profile_screen.dart#L188-L208) | `setPrimaryWallet` persists to Supabase, but adding new wallets fails to persist due to missing `addWallet` hookup. |
| **Web Application** | **NOT IMPLEMENTED** | *Entire repository* | No web application or web entrypoint exists in this repository. |
| **Admin / Dispatch Dashboard** | **NOT IMPLEMENTED** | *Entire repository* | No administrative portal or mechanic dispatch panel exists. |
| **Mechanic / Provider App** | **NOT IMPLEMENTED** | *Entire repository* | No provider-facing interface for mechanics to receive dispatch requests or submit quotes. |

---

## 5. Backend and Database Assessment

### 5.1 Supabase Integration Status
Supabase is initialized directly in `lib/main.dart` (lines 25-28):
```dart
await Supabase.initialize(
  url: 'https://rgzmoqpkugpcqfryrjkj.supabase.co',
  anonKey: 'sb_publishable_Brh5ctiNGrTdmKlVG2sHwA_aFWPlkAt',
);
```

### 5.2 Database Entities Currently Utilized
Based on `lib/services/supabase_service.dart`, the app queries only 4 tables:
1. `profiles`: `id`, `full_name`, `phone`, `updated_at`, `is_nid_verified`.
2. `vehicles`: `id`, `profile_id`, `model`, `plate`, `type`, `fuel`, `is_primary`, `created_at`.
3. `emergency_contacts`: `id`, `profile_id`, `name`, `phone`, `relation`, `created_at`.
4. `wallets`: `id`, `profile_id`, `provider`, `account_number`, `is_primary`, `created_at`.

### 5.3 Critical Architecture Flaw: Shared Mock Identity
In `lib/services/supabase_service.dart`:
```dart
static const String defaultProfileId = 'a0000000-0000-0000-0000-000000000001';
String get currentProfileId => defaultProfileId;
```
- **Finding:** The application completely bypasses Supabase Auth session tokens (`supabase.auth.currentUser?.id`).
- **Impact:** Any user running the app queries and mutates the exact same user profile, vehicle list, emergency contacts, and wallets. Multi-tenancy and user privacy are entirely absent.

### 5.4 Missing Database Entities
To function as a roadside emergency platform, the following database schema components are completely missing from the existing codebase:
- `mechanics` / `workshops` (profile, location/PostGIS point, verification status, rating, active status)
- `service_requests` (motorist_id, mechanic_id, status, breakdown_type, location, symptoms, notes, priority)
- `quotations` (request_id, breakdown of fees, total_amount, status)
- `service_categories` & `standard_rates`
- `mechanic_locations` (real-time spatial tracking / telemetry)
- `transactions` / `payments` (MFS escrow, payment status)
- `reviews` / `ratings`

---

## 6. Security Assessment

### 6.1 Vulnerabilities & Findings

1. **Hardcoded Supabase Credentials in Source Code**
   - **Severity:** HIGH
   - **Location:** [`lib/main.dart:L26-L27`](file:///c:/Users/aahad/ROADIX-Mobile/lib/main.dart#L26-L27)
   - **Finding:** Supabase URL (`https://rgzmoqpkugpcqfryrjkj.supabase.co`) and Anon Key (`sb_publishable_Brh5ctiNGrTdmKlVG2sHwA_aFWPlkAt`) are hardcoded strings in version control.
   - **Impact:** Anyone with read access to the repo or decompiled APK has access to the public key. While Supabase anon keys are intended to be public, they rely on Row Level Security (RLS) to restrict data.

2. **Absence of User Authentication & RLS Bypass**
   - **Severity:** CRITICAL
   - **Location:** [`lib/services/supabase_service.dart:L11-L13`](file:///c:/Users/aahad/ROADIX-Mobile/lib/services/supabase_service.dart#L11-L13)
   - **Finding:** App queries tables directly with a hardcoded UUID without signing in or passing an authenticated JWT.
   - **Impact:** For these queries to succeed on Supabase, Row Level Security (RLS) must either be **disabled** on those tables, or configured to allow anonymous reads/writes to `a0000000-0000-0000-0000-000000000001`. If RLS is disabled, anyone with the anon key can read and overwrite all customer profiles and vehicles.

3. **Missing iOS Privacy Permissions (Guaranteed App Store Rejection / Crash)**
   - **Severity:** HIGH
   - **Location:** [`ios/Runner/Info.plist`](file:///c:/Users/aahad/ROADIX-Mobile/ios/Runner/Info.plist)
   - **Finding:** No `NSLocationWhenInUseUsageDescription` or `NSLocationAlwaysAndWhenInUseUsageDescription` keys are defined in the iOS plist.
   - **Impact:** The app will crash immediately on iOS when `Geolocator.requestPermission()` is executed. Apple App Store will also automatically reject the binary.

4. **Authentication Bypass in UI**
   - **Severity:** MEDIUM
   - **Location:** [`lib/screens/login_screen.dart:L78-L84`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/login_screen.dart#L78-L84)
   - **Finding:** The Login screen provides a "Skip to SOS" button that routes directly to `EmergencyHomeScreen`. OTP verification also accepts arbitrary 6-digit input.
   - **Impact:** No identity verification is enforced anywhere in the motorist journey.

---

## 7. Code Quality Assessment

### 7.1 Static Analysis Evaluation Note
During this audit, an initial automated `dart analyze` execution via PowerShell background runner hung due to the Windows Dart batch wrapper (`C:\src\flutter\bin\dart.bat`) stalling on standard I/O pipes. The process was cleanly terminated (`task-209`), and the audit continued via direct manual AST and source-code inspection of all 26 Dart files.

### 7.2 Findings from Source Code Inspection
- **Swallowed Exceptions:**
  [`lib/services/supabase_service.dart:L27-L29`](file:///c:/Users/aahad/ROADIX-Mobile/lib/services/supabase_service.dart#L27-L29):
  ```dart
  } catch (e) {
    return null;
  }
  ```
  Network errors, Postgres exceptions, or format errors are silently discarded, making debugging in production impossible.
- **Missing Resource Cleanup:**
  In several modal widgets (`WalletEditorSheet`, `SearchBottomSheet`), controllers are initialized inside `State`, but `dispose()` behavior should be audited against complex rebuild trees.
- **Lack of Null-Safety Guarantees in Dynamic Maps:**
  In `ProfileScreen` lines 48-50:
  ```dart
  _userName = profile['full_name'] ?? 'Motorist';
  _userPhone = profile['phone'] ?? '';
  _isNidVerified = profile['is_nid_verified'] ?? false;
  ```
  Because `profile` is an untyped `Map<String, dynamic>`, changes in Postgres column names or casing will result in silent defaults rather than compile-time errors.
- **Unused Test Suite:**
  `test/widget_test.dart` is the stock counter test and does not verify any ROADIX widget or logic.

---

## 8. Technical Problems and Critical Bugs

### Bug 1: Telemetry Severing in Emergency Wizard
- **Location:** [`lib/screens/location_confirm_screen.dart:L404-L412`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/location_confirm_screen.dart#L404-L412)
- **Problem:** When confirming location, the app navigates to `VehicleSelectScreen` with:
  ```dart
  MaterialPageRoute(
    builder: (_) => VehicleSelectScreen(
      selectedFault: widget.selectedFault,
    ),
  )
  ```
- **Impact:** `initialLat`, `initialLng`, and the map center coordinates are completely dropped. The technician triage system has no idea where the vehicle is stranded.

### Bug 2: Diagnostic Notes Severing
- **Location:** [`lib/screens/fault_details_screen.dart:L424-L436`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/fault_details_screen.dart#L424-L436)
- **Problem:** When navigating from `FaultDetailsScreen` to `DispatchScreen`, the text from `_notesController.text` is not passed into the `DispatchScreen` constructor.
- **Impact:** Customer-specified landmarks (e.g. "Parked near Aarong gate, smells like burning rubber") are permanently lost.

### Bug 3: Broken Wallet Addition Persistence
- **Location:** [`lib/screens/profile_screen.dart:L198-L207`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/profile_screen.dart#L198-L207)
- **Problem:** `_openWalletEditor` receives updated wallets from `WalletEditorSheet`. Newly added wallets do not have an `id`. The callback only checks for `primary['id'] != null` and calls `setPrimaryWallet()`. It **never calls `_db.addWallet()`**.
- **Impact:** Any new bKash/Nagad wallet added by the user vanishes from the screen as soon as `_loadProfileData()` finishes.

### Bug 4: Emergency SOS Fails to Trigger Phone Call
- **Location:** [`lib/screens/sos_screen.dart:L34-L45`](file:///c:/Users/aahad/ROADIX-Mobile/lib/screens/sos_screen.dart#L34-L45)
- **Problem:** The 999 panic dialer only displays a `SnackBar` upon countdown completion.
- **Impact:** In an actual life-or-death highway collision or armed robbery scenario, the app fails to open the device dialer or connect the call to emergency services.

---

## 9. Missing or Unverified Components

1. **Web Application:** Completely missing from the repository.
2. **Backend Services & APIs:** No custom backend exists. The app relies solely on direct client-to-Supabase PostgREST queries.
3. **Database Migrations:** No migration scripts, SQL schema definitions, or seed scripts exist in the repository.
4. **Mechanic Discovery Engine:** No geospatial query (e.g., PostGIS `ST_DWithin`) or matching algorithm exists.
5. **Realtime WebSockets / Telemetry:** Real-time driver/mechanic position updates are not implemented.
6. **Push Notifications:** No Firebase Cloud Messaging (FCM) or Apple Push Notification Service (APNs) integration.
7. **Payment Gateway:** No integration with bKash, Nagad, or SSLCommerz payment APIs.
8. **Automated Testing:** 0% unit, integration, or widget test coverage for the ROADIX codebase.

---

## 10. Recommended Priorities for Remediation

### Phase 1: Security & Foundation (Immediate)
1. **Move Secrets to Environment:** Remove hardcoded Supabase URL and anon key from `lib/main.dart`; implement `.env` via `flutter_dotenv` or compile-time `--dart-define`.
2. **Add iOS Permissions:** Add `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` to `ios/Runner/Info.plist`.
3. **Implement Real Supabase Auth:** Replace mock PIN pad and fake OTP with `supabase.auth.signInWithOtp()` and `supabase.auth.verifyOTP()`.
4. **Bind Profile to Auth Session:** Update `SupabaseService.currentProfileId` to dynamically return `supabase.auth.currentUser!.id` and enforce Supabase RLS.

### Phase 2: State Management & Architecture Cleanup (Short-Term)
1. **Prune Ghost Dependencies:** Remove unused packages (`drift`, `sqlite3_flutter_libs`, `dio`, `latlong2`, `path_provider`) from `pubspec.yaml`, or integrate `flutter_bloc` and `get_it` properly if intended.
2. **Create Domain Models:** Replace untyped `Map<String, dynamic>` with immutable typed models (`UserProfile`, `Vehicle`, `EmergencyContact`, `Wallet`, `ServiceRequest`).
3. **Fix Data Flow in Emergency Wizard:** Pass geographic coordinates (`LatLng`) and triage `notes` through the entire wizard state down to the dispatch screen.

### Phase 3: Core Business Logic & Backend Expansion (Medium-Term)
1. **Database Schema Setup:** Create migration scripts for `mechanics`, `service_requests`, `quotations`, and PostGIS spatial indexing.
2. **Real Emergency SOS:** Integrate `url_launcher` to genuinely trigger `tel:999` and send automated SMS via Twilio/local SMS gateway to saved emergency contacts.
3. **Real Dispatch & Quotations:** Replace simulated 3-second timer with genuine Supabase insert into `service_requests` and subscribe to real-time status updates via Supabase Realtime channels.
4. **Fix Wallet Persistence:** Connect `WalletEditorSheet` to `SupabaseService.addWallet()`.
