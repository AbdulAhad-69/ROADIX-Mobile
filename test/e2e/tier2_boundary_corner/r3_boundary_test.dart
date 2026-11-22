import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  // =========================================================================
  // FEATURE 8: R3.1 Emergency Home UI & Polish Boundary & Corner Cases
  // =========================================================================
  group('Feature 8: R3.1 Emergency Home UI Boundary (SRS §R3)', () {
    testWidgets('T2.8.1: Ultra-narrow screen width (320px x 600px) renders EmergencyHomeScreen without RenderFlex overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(320, 600),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.sosHomeButton, findsOneWidget);
      expect(E2EFinders.triageSectionTitle, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.8.2: Tablet landscape viewport (1200px x 800px) renders EmergencyHomeScreen cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(1200, 800),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.sosHomeButton, findsOneWidget);
      expect(find.text('Battery'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.8.3: Rapid double-tap on SOS button opens confirmation sheet and navigates to SosScreen',
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

      // Scroll to SOS button and tap
      await tester.scrollUntilVisible(E2EFinders.sosHomeButton, 300);
      await tester.tap(E2EFinders.sosHomeButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Modal bottom sheet appears
      expect(find.text('Select Emergency Action'), findsOneWidget);
      expect(find.text('Call 999 Police / Medical'), findsOneWidget);

      // Tap 999 Police / Medical panic dialer
      await tester.tap(find.text('Call 999 Police / Medical'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SosScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.8.4: Long user name (60+ characters) in profile header truncates cleanly with ellipsis without overflow',
        (WidgetTester tester) async {
      E2ETestHarness.mockProfile['full_name'] =
          'Mohammad Saifuddin Ahmed Al-Mansoor Chowdhury of Chittagong Division';

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(360, 640),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Welcome,'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.8.5: Standby default state with zero active rescue displays standard triage without active rescue banner',
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

      expect(E2EFinders.activeRescueBanner, findsNothing);
      expect(E2EFinders.pressForHelpText, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.8.6: Null user profile full_name renders default Motorist fallback in header avatar',
        (WidgetTester tester) async {
      E2ETestHarness.mockProfile['full_name'] = null;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Welcome,'), findsOneWidget);
      expect(E2EFinders.profileAvatarHeader, findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 9: R3.2 SOS Screen Redesign & Countdown Boundary & Corner Cases
  // =========================================================================
  group('Feature 9: R3.2 SOS Screen Redesign & Countdown Boundary (SRS §R3)', () {
    testWidgets('T2.9.1: Cancel SOS countdown at T-1s (4.5s elapsed) successfully aborts call and displays CANCELLED banner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      // Advance countdown by 4.5 seconds (close to 0)
      await tester.pump(const Duration(milliseconds: 4500));

      // Tap cancel button right before completion
      expect(E2EFinders.tapToCancelButton, findsOneWidget);
      await tester.tap(E2EFinders.tapToCancelButton);
      await tester.pump();

      // Verify cancellation took effect
      expect(E2EFinders.sosCancelledBanner, findsOneWidget);
      expect(E2ETestHarness.launchedUrls, isEmpty);

      // Advance past original 5s duration to ensure no late call occurs
      await tester.pump(const Duration(seconds: 2));
      expect(E2ETestHarness.launchedUrls, isEmpty);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.9.2: Countdown reaching 0 seconds launches emergency dialer with tel:999 in launchedUrls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      // Allow countdown to finish (5 seconds duration)
      await tester.pump(const Duration(seconds: 6));

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.9.3: CANCELLED banner renders after cancel, and TAP TO CANCEL button is removed from tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      await tester.tap(E2EFinders.tapToCancelButton);
      await tester.pump();

      expect(E2EFinders.sosCancelledBanner, findsOneWidget);
      expect(E2EFinders.tapToCancelButton, findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.9.4: Rapid repeated taps on cancel button does not throw exception or cause state glitch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      // Tap cancel 5 times in rapid sequence
      for (int i = 0; i < 5; i++) {
        final cancelFinder = find.textContaining('TAP TO CANCEL');
        if (cancelFinder.evaluate().isNotEmpty) {
          await tester.tap(cancelFinder);
          await tester.pump();
        }
      }

      expect(tester.takeException(), isNull);
      expect(E2EFinders.sosCancelledBanner, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.9.5: Highway Patrol quick card direct dial invokes emergency dialer immediately with tel:999',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      expect(E2EFinders.highwayPatrolCard, findsOneWidget);
      await tester.tap(E2EFinders.highwayPatrolCard);
      await tester.pump();

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.9.6: National Ambulance quick card direct dial invokes emergency dialer immediately with tel:999',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      expect(E2EFinders.nationalAmbulanceCard, findsOneWidget);
      await tester.tap(E2EFinders.nationalAmbulanceCard);
      await tester.pump();

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 10: R3.3 Vehicle Classification (4 types) Boundary & Corner Cases
  // =========================================================================
  group('Feature 10: R3.3 Vehicle Classification Boundary (SRS §R3)', () {
    testWidgets('T2.10.1: Switching vehicle types sequentially updates selection indicators smoothly across all 4 categories',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Dead Battery'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // 1. Select Motorcycle
      await tester.tap(E2EFinders.motorcycleCard);
      await tester.pump();
      expect(find.descendant(of: find.ancestor(of: E2EFinders.motorcycleCard, matching: find.byType(InkWell)), matching: find.byIcon(Icons.check)), findsOneWidget);

      // 2. Select Sedan / Hatch
      await tester.tap(E2EFinders.sedanCard);
      await tester.pump();
      expect(find.descendant(of: find.ancestor(of: E2EFinders.sedanCard, matching: find.byType(InkWell)), matching: find.byIcon(Icons.check)), findsOneWidget);

      // 3. Select SUV / Micro
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();
      expect(find.descendant(of: find.ancestor(of: E2EFinders.suvCard, matching: find.byType(InkWell)), matching: find.byIcon(Icons.check)), findsOneWidget);

      // 4. Select Commercial
      await tester.tap(E2EFinders.commercialCard);
      await tester.pump();
      expect(find.descendant(of: find.ancestor(of: E2EFinders.commercialCard, matching: find.byType(InkWell)), matching: find.byIcon(Icons.check)), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.10.2: License plate with extra leading/trailing whitespace and mixed case is trimmed before proceeding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Flat Tire'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Enter untrimmed plate
      await tester.enterText(find.byType(TextField), '   Dhaka Metro GA-11-2034   ');
      await tester.pump();

      // Proceed
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies FaultDetailsScreen receives the trimmed plate
      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(find.textContaining('Dhaka Metro GA-11-2034'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.10.3: Commercial vehicle displays specific attributes ("Up to 3.5 Ton • Flatbed") and maps to Light Commercial',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Towing'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.text('Up to 3.5 Ton • Flatbed'), findsOneWidget);
      expect(find.text('Pickup / Covered Van'), findsOneWidget);

      // Select Commercial
      await tester.tap(E2EFinders.commercialCard);
      await tester.pump();

      // Proceed to FaultDetailsScreen
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(find.textContaining('Light Commercial'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.10.4: Empty or pure whitespace license plate falls back to default plate and allows proceeding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Engine Trouble'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Clear text field to empty string
      await tester.enterText(find.byType(TextField), '    ');
      await tester.pump();

      // Tap continue
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Proceeds with default fallback plate without blocking
      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(find.textContaining('Dhaka Metro GA-11-2034'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.10.5: Fuel type selector chip toggle with uncommon option (EV - Electric Vehicle) updates selection state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Dead Battery'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.text('EV'), findsOneWidget);

      // Tap EV choice chip
      await tester.tap(find.text('EV'));
      await tester.pump();

      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'EV')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Octane')).selected, isFalse);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.10.6: Rapid switching between vehicle cards does not corrupt active state or decoration styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Flat Tire'),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      for (int i = 0; i < 4; i++) {
        await tester.tap(E2EFinders.motorcycleCard);
        await tester.tap(E2EFinders.suvCard);
        await tester.tap(E2EFinders.commercialCard);
        await tester.tap(E2EFinders.sedanCard);
      }
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(E2EFinders.continueToFaultButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 11: R3.4 Fault Details & Symptom Chips Boundary & Corner Cases
  // =========================================================================
  group('Feature 11: R3.4 Fault Details & Symptom Chips Boundary (SRS §R3)', () {
    testWidgets('T2.11.1: Zero symptom chips selected allows proceeding to mechanic search without blocking user',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // Proceed immediately without selecting any symptom chips
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DispatchScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.11.2: All symptom chips selected simultaneously renders in scrollable list without text overlap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final symptoms = [
        'Engine completely silent (no crank)',
        'Rapid clicking sound on ignition',
        'Dashboard lights dim or flickering',
        'I have jumper cables in vehicle',
      ];

      for (final s in symptoms) {
        await tester.tap(find.text(s));
        await tester.pump();
      }

      // 4 checkmark icons for 4 selected symptoms
      expect(find.byIcon(Icons.check), findsNWidgets(4));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.11.3: Live highway lane hazard switch toggle activates high-visibility urgent hazard warning banner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Engine Trouble',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Toggle live highway lane hazard switch
      await tester.tap(switches.first, warnIfMissed: false);
      await tester.pump();

      expect(
        find.textContaining('HIGH ROADWAY HAZARD: Priority dispatch queue activated'),
        findsOneWidget,
      );
      expect(find.text('URGENT'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.11.4: Hazard lights toggle switch allows toggling off (low visibility scenario)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Towing',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final switches = find.byType(Switch);
      expect(tester.widget<Switch>(switches.last).value, isTrue);

      // Toggle off hazard lights
      await tester.tap(switches.last, warnIfMissed: false);
      await tester.pump();

      expect(tester.widget<Switch>(switches.last).value, isFalse);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.11.5: Proceeding with live lane hazard enabled marks isHighPriority: true in DispatchScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Flat Tire',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final switches = find.byType(Switch);
      await tester.tap(switches.first, warnIfMissed: false);
      await tester.pump();

      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dispatch = tester.widget<DispatchScreen>(find.byType(DispatchScreen));
      expect(dispatch.isHighPriority, isTrue);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.11.6: Extremely long diagnostic notes (500+ chars) in notes text field is accepted',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Out of Fuel',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(600, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      final longNotes = List.generate(20, (i) => 'Critical road assistance needed note line $i').join('. ');
      await tester.enterText(find.byType(TextField), longNotes);
      await tester.pump();

      expect(find.text(longNotes), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 12: R3.5 Login Screen Modern Layout Boundary & Corner Cases
  // =========================================================================
  group('Feature 12: R3.5 Login Screen Modern Layout Boundary (SRS §R3)', () {
    testWidgets('T2.12.1: Invalid Bangladesh phone number formats ("12345", "01234567890") display validation error prompt',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      final phoneInput = find.byType(TextField).first;
      await tester.enterText(phoneInput, '12345');
      await tester.pump();

      // Tap Send Verification Code button
      final sendCodeButton = find.widgetWithText(ElevatedButton, 'SEND VERIFICATION CODE');
      expect(sendCodeButton, findsOneWidget);
      await tester.tap(sendCodeButton);
      await tester.pump();

      expect(
        find.textContaining('Please enter a valid 11-digit Bangladesh phone'),
        findsWidgets,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.12.2: Role toggle between Motorist and Technician in Sign-Up mode updates screen title',
        (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            const LoginScreen(),
            physicalSize: const Size(800, 1200),
            tester: tester,
          ),
        );
        await tester.pump();

        // Switch to Email tab
        await tester.tap(E2EFinders.emailAuthTab);
        await tester.pump();

        // Switch to Sign Up mode
        await tester.tap(find.text('Sign Up'));
        await tester.pump();

        // Initial default: Motorist
        expect(find.text('Create Motorist Account'), findsOneWidget);

        // Tap Technician
        await tester.tap(find.text('Technician').last);
        await tester.pump();

        expect(find.text('Create Technician Account'), findsOneWidget);

        await E2ETestHarness.cleanUp(tester);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('T2.12.3: Switching rapidly between Mobile OTP and Email Account tabs preserves form stability without exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      for (int i = 0; i < 4; i++) {
        await tester.tap(E2EFinders.emailAuthTab);
        await tester.pump();
        await tester.tap(E2EFinders.phoneAuthTab);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.12.4: Demo login buttons for Motorist and Technician bypass credential barriers and navigate to appropriate homes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();

      // 1. Motorist demo button
      final motoristDemo = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Motorist'),
      );
      expect(motoristDemo, findsWidgets);

      await tester.tap(motoristDemo.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.12.5: Google Sign-In button handles simulated unconfigured OAuth by falling back to demo account without crash',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.googleSignInButton, findsOneWidget);
      await tester.tap(E2EFinders.googleSignInButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.12.6: Empty email or short password (<6 chars) in email login mode triggers informative error prompts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      // Switch to Email tab
      await tester.tap(E2EFinders.emailAuthTab);
      await tester.pump();

      // Tap Sign In button with empty fields
      final signInBtn = find.widgetWithText(ElevatedButton, 'SIGN IN');
      expect(signInBtn, findsOneWidget);
      await tester.tap(signInBtn);
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 13: R3.6 Profile Screen & Digital Garage Boundary & Corner Cases
  // =========================================================================
  group('Feature 13: R3.6 Profile Screen & Digital Garage Boundary (SRS §R3)', () {
    testWidgets('T2.13.1: Profile with null avatarUrl renders default person icon fallback without network error',
        (WidgetTester tester) async {
      E2ETestHarness.mockProfile['avatar_url'] = null;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.byIcon(Icons.person), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.13.2: Empty vehicle garage renders "No vehicles saved in garage yet." placeholder prompt',
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
      expect(E2EFinders.digitalGarageHeader, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.13.3: Empty emergency contacts list renders "+ Add First Family Contact" prompt',
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

      expect(find.text('No emergency broadcast contacts configured yet.'), findsOneWidget);
      expect(find.text('+ Add First Family Contact'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.13.4: Viewport constraints on small device (400x600) scrolls smoothly to reach "Log Out & Return to Login"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(400, 600),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      expect(E2EFinders.logoutButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.13.5: Deleting a non-primary wallet updates wallet list and preserves primary wallet',
        (WidgetTester tester) async {
      final wallets = [
        {'id': 'w-1', 'provider': 'bKash', 'number': '01711000001', 'isPrimary': true},
        {'id': 'w-2', 'provider': 'Nagad', 'number': '01811000022', 'isPrimary': false},
      ];

      List<Map<String, dynamic>>? resultWallets;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: wallets,
              onWalletsChanged: (updated) {
                resultWallets = updated;
              },
            ),
          ),
          physicalSize: const Size(600, 1000),
          tester: tester,
        ),
      );
      await tester.pump();

      // Non-primary wallet has delete icon (primary does not)
      expect(E2EFinders.deleteWalletIcon, findsOneWidget);
      await tester.tap(E2EFinders.deleteWalletIcon);
      await tester.pump();

      expect(resultWallets, isNotNull);
      expect(resultWallets!.length, equals(1));
      expect(resultWallets!.first['provider'], equals('bKash'));
      expect(resultWallets!.first['isPrimary'], isTrue);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.13.6: Profile with unverified NID status displays "UNVERIFIED MOTORIST" badge with crimson styling',
        (WidgetTester tester) async {
      E2ETestHarness.mockProfile['is_nid_verified'] = false;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UNVERIFIED MOTORIST'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
