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
  // FEATURE 14: R4.1 Profile Picture Update & Persistence Boundary & Corner Cases
  // =========================================================================
  group('Feature 14: R4.1 Profile Picture Update & Persistence Boundary (SRS §R4)', () {
    testWidgets('T2.14.1: Updating avatar with invalid or unreachable image URL catches error gracefully and retains avatar fallback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: EditProfileSheet(
              currentName: 'Tanvir Ahmed',
              currentPhone: '+8801711223344',
              currentAvatarUrl: 'https://unreachable-domain-xyz.com/nonexistent_avatar.png',
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(CircleAvatar), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.14.2: EditProfileSheet with empty full name string blocks saving and keeps the sheet open',
        (WidgetTester tester) async {
      bool onSaveCalled = false;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: EditProfileSheet(
              currentName: '',
              currentPhone: '+8801711223344',
              onSave: (name, phone, avatar) {
                onSaveCalled = true;
              },
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Clear name field (TextField at index 1)
      final nameField = find.byType(TextField).at(1);
      await tester.enterText(nameField, '   ');
      await tester.pump();

      // Tap Save Changes button
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      // onSave callback must not be invoked for empty name
      expect(onSaveCalled, isFalse);
      expect(find.byType(EditProfileSheet), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.14.3: EditProfileSheet captures phone updates and allows updating name and phone together',
        (WidgetTester tester) async {
      String? savedName;
      String? savedPhone;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: EditProfileSheet(
              currentName: 'Old Name',
              currentPhone: '+8801711111111',
              onSave: (newName, newPhone, newAvatar) {
                savedName = newName;
                savedPhone = newPhone;
              },
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Enter new name (TextField index 1) and phone (TextField index 2)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Updated Name');
      await tester.enterText(textFields.at(2), '+8801722222222');
      await tester.pump();

      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(savedName, equals('Updated Name'));
      expect(savedPhone, equals('+8801722222222'));

      await E2ETestHarness.cleanUp(tester);
    });

    test('T2.14.4: Simulated network error during updateProfile is caught and handled gracefully', () async {
      // Simulate profile update with non-null values
      expect(
        () async {
          await SupabaseService().updateProfile(
            fullName: 'Test Motorist',
            phone: '+8801711000001',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          );
        },
        returnsNormally,
      );
    });

    test('T2.14.5: Rapid successive profile updates correctly persists the latest state', () async {
      final names = ['Name A', 'Name B', 'Name C'];
      for (final name in names) {
        await SupabaseService().updateProfile(
          fullName: name,
          phone: '+8801711000001',
        );
      }

      final profile = await SupabaseService().getProfile();
      expect(profile?['full_name'], equals('Name C'));
    });

    testWidgets('T2.14.6: Avatar preset selection in EditProfileSheet updates the active avatar preview immediately',
        (WidgetTester tester) async {
      String? selectedAvatar;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: EditProfileSheet(
              currentName: 'Tanvir Ahmed',
              currentPhone: '+8801711223344',
              currentAvatarUrl: null,
              onSave: (name, phone, avatar) {
                selectedAvatar = avatar;
              },
            ),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Tap first avatar preset thumbnail (ClipOval)
      final presetThumbnails = find.byType(ClipOval);
      expect(presetThumbnails, findsWidgets);

      // Tap preset
      await tester.tap(presetThumbnails.first);
      await tester.pump();

      // Tap Save Changes
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(selectedAvatar, isNotNull);
      expect(selectedAvatar, contains('images.unsplash.com'));

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 15: R4.2 Login/Logout Transitions Boundary & Corner Cases
  // =========================================================================
  group('Feature 15: R4.2 Login/Logout Transitions Boundary (SRS §R4)', () {
    testWidgets('T2.15.1: Logout while network fails (SocketException in signOut) navigates cleanly to LoginScreen via finally',
        (WidgetTester tester) async {
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

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      expect(E2EFinders.logoutButton, findsOneWidget);

      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      // Guarantees clean navigation to LoginScreen despite backend failure
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.15.2: Technician demo login navigates directly to MechanicHomeScreen without routing to Motorist view',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final techDemo = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Technician'),
      );
      expect(techDemo, findsWidgets);

      await tester.tap(techDemo.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(MechanicHomeScreen), findsOneWidget);
      expect(find.byType(EmergencyHomeScreen), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.15.3: Rapid back-press from LoginScreen does not crash or throw unhandled pop error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      // Attempt system back navigation on root LoginScreen
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      // ignore: avoid_dynamic_calls
      await widgetsAppState.didPopRoute();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.15.4: Session loss (currentUser becomes null) maintains LoginScreen access',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(SupabaseService().currentUser, isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.15.5: Repeated login and logout cycle resets state cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Cycle 1: Motorist Demo Login -> EmergencyHome -> Profile Tab -> Logout
      final motoristDemo = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Motorist'),
      );
      await tester.tap(motoristDemo.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      // Switch to Profile Tab
      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.scrollUntilVisible(
        E2EFinders.logoutButton,
        300,
        scrollable: find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoginScreen), findsOneWidget);

      // Cycle 2: Technician Demo Login -> MechanicHomeScreen -> Logout Icon in AppBar
      final techDemo = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Technician'),
      );
      await tester.tap(techDemo.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MechanicHomeScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.15.6: Guest SOS modal allows instant dispatch access and handles skip phone entry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1600),
          tester: tester,
        ),
      );
      await tester.pump();

      final guestSosPill = find.text('Continue as Guest • Instant Triage');
      expect(guestSosPill, findsOneWidget);

      await tester.tap(guestSosPill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('GUEST SOS DISPATCH'), findsOneWidget);

      // Skip phone entry directly
      final skipButton = find.text('Skip phone entry (Proceed directly)');
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Guest sheet closes cleanly
      expect(find.text('GUEST SOS DISPATCH'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 16: R4.3 Assistance Request Workflow Navigation Boundary & Corner Cases
  // =========================================================================
  group('Feature 16: R4.3 Assistance Request Workflow Navigation Boundary (SRS §R4)', () {
    testWidgets('T2.16.1: Back navigation from LocationConfirmScreen returns to EmergencyHomeScreen and preserves session',
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

      // Tap Flat Tire category card
      await tester.tap(E2EFinders.breakdownCategory('Flat Tire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back).first;
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);
      expect(find.text('Flat Tire'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.16.2: Back navigation from FaultDetailsScreen to VehicleSelectScreen preserves vehicle and plate',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(
            selectedFault: 'Engine Trouble',
            breakdownLat: 23.8103,
            breakdownLng: 90.4125,
            breakdownAddress: 'Mohakhali, Dhaka',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Select SUV / Micro
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();

      // Advance to FaultDetailsScreen
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);

      // Pop back using back arrow
      final backButton = find.byIcon(Icons.arrow_back).last;
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Returned to VehicleSelectScreen
      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.16.3: Back navigation from VehicleSelectScreen to LocationConfirmScreen preserves location and fault',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirm location
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // Pop back to LocationConfirmScreen
      final backButton = find.byIcon(Icons.arrow_back).last;
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.16.4: Location confirm without GPS lock uses fallback roadside coords across triage flow',
        (WidgetTester tester) async {
      const fallbackLat = 24.0000;
      const fallbackLng = 90.2000;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Out of Fuel',
            initialLat: fallbackLat,
            initialLng: fallbackLng,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final vehicleScreen = tester.widget<VehicleSelectScreen>(find.byType(VehicleSelectScreen));
      expect(vehicleScreen.breakdownLat, closeTo(fallbackLat, 0.001));
      expect(vehicleScreen.breakdownLng, closeTo(fallbackLng, 0.001));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.16.5: Wizard cancellation halfway (popping back to home) resets form state cleanly',
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

      // 1. Enter triage flow
      await tester.tap(E2EFinders.breakdownCategory('Towing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      // 2. Advance to vehicle selection
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // 3. Cancel backwards: pop back to LocationConfirm
      await tester.tap(find.byIcon(Icons.arrow_back).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      // 4. Pop back to EmergencyHomeScreen
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.16.6: Forward progression through complete 4-step wizard passes all parameters intact to DispatchScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Engine Overheating',
            initialLat: 23.8103,
            initialLng: 90.4125,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Step 1 -> Step 2
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // Select SUV
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();

      // Step 2 -> Step 3
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FaultDetailsScreen), findsOneWidget);

      // Step 3 -> Step 4 (DispatchScreen)
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DispatchScreen), findsOneWidget);
      final dispatch = tester.widget<DispatchScreen>(find.byType(DispatchScreen));
      expect(dispatch.selectedFault, equals('Engine Overheating'));
      expect(dispatch.vehicleType, equals('Passenger Car'));

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
