import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/services/demo_session.dart';
import 'package:roadix_mobile/services/supabase_service.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  // =========================================================================
  // FEATURE 14: R4.1 Profile Picture Update & Persistence (SRS §R4)
  // =========================================================================
  group('Feature 14: R4.1 Profile Picture Update & Persistence (SRS §R4)', () {
    testWidgets('T1.14.1: ProfileScreen renders profile avatar with person icon fallback when avatarUrl is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.byIcon(Icons.person), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.14.2: ProfileScreen displays edit button invoking profile identity editor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.editProfileButton, findsOneWidget);

      await tester.tap(E2EFinders.editProfileButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EditProfileSheet), findsOneWidget);
      expect(find.text('SAVE CHANGES'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.14.3: EditProfileSheet populates current name, phone, and renders avatar presets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: EditProfileSheet(
              currentName: 'Rahim Khan',
              currentPhone: '+8801712345678',
              currentAvatarUrl: null,
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.byType(EditProfileSheet), findsOneWidget);
      expect(find.text('Rahim Khan'), findsOneWidget);
      expect(find.text('+8801712345678'), findsOneWidget);
      expect(find.text('SAVE CHANGES'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.14.4: Tapping "SAVE CHANGES" invokes onSave callback with updated profile information',
        (WidgetTester tester) async {
      String? savedName;
      String? savedPhone;
      String? savedAvatar;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: EditProfileSheet(
              currentName: 'Tanvir Ahmed',
              currentPhone: '+8801711223344',
              currentAvatarUrl: null,
              onSave: (newName, newPhone, newAvatarUrl) {
                savedName = newName;
                savedPhone = newPhone;
                savedAvatar = newAvatarUrl;
              },
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(savedName, equals('Tanvir Ahmed'));
      expect(savedPhone, equals('+8801711223344'));
      expect(savedAvatar, isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.14.5: EmergencyHomeScreen header displays user initial letter fallback in avatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.profileAvatarHeader, findsWidgets);
      expect(find.textContaining('Welcome,'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.14.6: SupabaseService updateProfile blocks unauthenticated REST writes and persists avatarUrl in Demo Mode', () async {
      addTearDown(DemoSession.clear);
      const newAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
      const newName = 'Asif Mahmud';
      const newPhone = '+8801799887766';

      // 1. Signed-out safety: no unauthorized REST write to hardcoded demo-motorist
      E2ETestHarness.lastRestPayload = null;
      await SupabaseService().updateProfile(
        fullName: newName,
        phone: newPhone,
        avatarUrl: newAvatar,
      );
      expect(E2ETestHarness.lastRestPayload, isNull);

      // 2. Demo mode update reflects immediately via getProfile()
      DemoSession.startDemo(demoRole: 'motorist');
      await SupabaseService().updateProfile(
        fullName: newName,
        phone: newPhone,
        avatarUrl: newAvatar,
      );

      final updatedProfile = await SupabaseService().getProfile();
      expect(updatedProfile, isNotNull);
      expect(updatedProfile!['avatar_url'], equals(newAvatar));
      expect(updatedProfile['full_name'], equals(newName));
      expect(updatedProfile['phone'], equals(newPhone));
    });
  });

  // =========================================================================
  // FEATURE 15: R4.2 Login/Logout Transitions (SRS §R4)
  // =========================================================================
  group('Feature 15: R4.2 Login/Logout Transitions (SRS §R4)', () {
    testWidgets('T1.15.1: Motorist one-tap demo login navigates cleanly to EmergencyHomeScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.text('DEMO ONE-TAP ACCESS'), findsOneWidget);

      await tester.tap(E2EFinders.motoristDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.15.2: Technician one-tap demo login navigates cleanly to MechanicHomeScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      await tester.tap(E2EFinders.mechanicDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(MechanicHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.15.3: ProfileScreen "Log Out & Return to Login" button initiates sign out transition',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 300);
      expect(E2EFinders.logoutButton, findsOneWidget);

      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.15.4: ProfileScreen logout try/catch/finally ensures LoginScreen navigation when signOut throws',
        (WidgetTester tester) async {
      // Simulate backend exception during signOut
      E2ETestHarness.onSignOutOverride = () async {
        throw const SocketException('Simulated network timeout/failure during signOut');
      };
      addTearDown(() {
        E2ETestHarness.onSignOutOverride = null;
      });

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 300);
      expect(E2EFinders.logoutButton, findsOneWidget);

      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      // Despite signOut() exception, finally block guaranteed route transition to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.15.5: Guest SOS quick action on LoginScreen opens guest dispatch sheet without credential gate',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final guestSosPill = find.text('Continue as Guest • Instant Triage');
      expect(guestSosPill, findsOneWidget);

      await tester.tap(guestSosPill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GUEST SOS DISPATCH'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.15.6: SupabaseService signOut clears session state without uncaught exception', () async {
      await SupabaseService().signOut();
      expect(SupabaseService().currentUser, isNull);
    });
  });

  // =========================================================================
  // FEATURE 16: R4.3 Assistance Request Workflow Navigation (SRS §R4)
  // =========================================================================
  group('Feature 16: R4.3 Assistance Request Workflow Navigation (SRS §R4)', () {
    testWidgets('T1.16.1: EmergencyHomeScreen breakdown selection opens LocationConfirmScreen with selected fault',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Flat Tire category
      await tester.tap(E2EFinders.breakdownCategory('Flat Tire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(find.text('Flat Tire'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.16.2: LocationConfirmScreen "CONFIRM LOCATION" advances to VehicleSelectScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Dead Battery'),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.confirmLocationButton, findsOneWidget);

      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      expect(E2EFinders.sedanCard, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.16.3: VehicleSelectScreen "CONTINUE TO FAULT DETAILS" passes vehicle and advances to FaultDetailsScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(
            selectedFault: 'Engine Overheating',
            breakdownLat: 23.8103,
            breakdownLng: 90.4125,
            breakdownAddress: 'Tejgaon, Dhaka',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Tap SUV / Micro
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();

      expect(E2EFinders.continueToFaultButton, findsOneWidget);
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(E2EFinders.heroFaultSummaryCard, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.16.4: FaultDetailsScreen "FIND NEARBY MECHANICS" pushes DispatchScreen with full payload',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Towing',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
            breakdownLat: 23.8103,
            breakdownLng: 90.4125,
            breakdownAddress: 'Tejgaon, Dhaka',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.requestMechanicButton, findsOneWidget);

      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // DispatchScreen is pushed
      expect(find.byType(DispatchScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.16.5: Back navigation from VehicleSelectScreen returns to LocationConfirmScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(selectedFault: 'Out of Fuel'),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Advance to VehicleSelectScreen
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // Pop back using active on-screen back button icon
      final backButton = find.byIcon(Icons.arrow_back).last;
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Restored LocationConfirmScreen
      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.16.6: Back navigation from FaultDetailsScreen returns to VehicleSelectScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(
            selectedFault: 'General Breakdown',
            breakdownLat: 23.8103,
            breakdownLng: 90.4125,
            breakdownAddress: 'Banani, Dhaka',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Advance to FaultDetailsScreen
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);

      // Pop back using active on-screen back button icon
      final backButton = find.byIcon(Icons.arrow_back).last;
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Restored VehicleSelectScreen
      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
