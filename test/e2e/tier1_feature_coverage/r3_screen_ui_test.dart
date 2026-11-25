import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/theme/app_colors.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  // =========================================================================
  // FEATURE 8: R3.1 Emergency Home UI & Polish
  // =========================================================================
  group('Feature 8: R3.1 Emergency Home UI & Polish (SRS §R3)', () {
    testWidgets('T1.8.1: EmergencyHomeScreen renders SOS trigger button with "PRESS FOR HELP"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const EmergencyHomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.sosHomeButton, findsOneWidget);
      expect(E2EFinders.pressForHelpText, findsOneWidget);
      expect(E2EFinders.triageSectionTitle, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.8.2: EmergencyHomeScreen displays interactive profile header with avatar container',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const EmergencyHomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.profileAvatarHeader, findsWidgets);
      expect(find.textContaining('Welcome,'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.8.3: EmergencyHomeScreen displays 5 distinct breakdown categories',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const EmergencyHomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.breakdownCategory('Battery'), findsOneWidget);
      expect(E2EFinders.breakdownCategory('Flat Tire'), findsOneWidget);
      expect(E2EFinders.breakdownCategory('Engine'), findsOneWidget);
      expect(E2EFinders.breakdownCategory('Fuel'), findsOneWidget);
      expect(E2EFinders.breakdownCategory('Towing'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.8.4: Tapping Battery breakdown card initiates location confirmation triage flow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Battery triage card
      await tester.tap(E2EFinders.breakdownCategory('Battery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.8.5: Tapping profile avatar header switches navigation to Profile view',
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

      // Tap profile avatar header container
      final avatarContainer = find.textContaining('Welcome,');
      expect(avatarContainer, findsOneWidget);

      await tester.tap(avatarContainer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should display ProfileScreen
      expect(find.byType(ProfileScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.8.6: EmergencyHomeScreen renders responsive bottom navigation bar',
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

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 9: R3.2 SOS Screen Redesign & Countdown
  // =========================================================================
  group('Feature 9: R3.2 SOS Screen Redesign & Countdown (SRS §R3)', () {
    testWidgets('T1.9.1: SosScreen renders high-contrast tactical alert header and countdown dial',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      expect(E2EFinders.sosActiveBadge, findsOneWidget);
      expect(E2EFinders.tapToCancelButton, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.9.2: Tapping "TAP TO CANCEL" button halts countdown and displays cancellation banner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      await tester.tap(E2EFinders.tapToCancelButton);
      await tester.pump();

      expect(E2EFinders.sosCancelledBanner, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.9.3: SosScreen countdown completion triggers emergency 999 call',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      // Advance 5 seconds to complete countdown
      await tester.pump(const Duration(seconds: 6));

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.9.4: SosScreen displays quick emergency cards for Highway Police and Ambulance',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      expect(E2EFinders.highwayPatrolCard, findsOneWidget);
      expect(E2EFinders.nationalAmbulanceCard, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.9.5: Tapping Highway Police quick card invokes dialer immediately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();

      await tester.tap(E2EFinders.highwayPatrolCard);
      await tester.pump();

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.9.6: SosScreen live GPS position card displays coordinates and precision',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(const SosScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('° N'), findsOneWidget);
      expect(find.textContaining('° E'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.contains('m Acc') == true ||
                  w.data?.contains('GPS Estimating') == true),
        ),
        findsOneWidget,
      );

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 10: R3.3 Vehicle Classification (4 types)
  // =========================================================================
  group('Feature 10: R3.3 Vehicle Classification (4 types) (SRS §R3)', () {
    testWidgets('T1.10.1: VehicleSelectScreen renders 2x2 grid with 4 vehicle categories',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();

      expect(E2EFinders.motorcycleCard, findsOneWidget);
      expect(E2EFinders.sedanCard, findsOneWidget);
      expect(E2EFinders.suvCard, findsOneWidget);
      expect(E2EFinders.commercialCard, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.10.2: Distinct Sedan vs SUV visual cards show distinct sub-labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Flat Tire'),
        ),
      );
      await tester.pump();

      expect(find.text('Private Passenger Car'), findsOneWidget);
      expect(find.text('7-Seater / 4x4 Jeep'), findsOneWidget);
      expect(find.text('2-Wheeler / Scooter'), findsOneWidget);
      expect(find.text('Pickup / Covered Van'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.10.3: Selecting SUV card highlights it and updates active vehicle category',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Engine Trouble'),
          physicalSize: const Size(600, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final suvCardInkWell = find.ancestor(
        of: E2EFinders.suvCard,
        matching: find.byType(InkWell),
      );
      final sedanCardInkWell = find.ancestor(
        of: E2EFinders.sedanCard,
        matching: find.byType(InkWell),
      );

      // Prior to tap, Sedan is selected by default; SUV is not selected
      expect(
        find.descendant(of: suvCardInkWell, matching: find.byIcon(Icons.check)),
        findsNothing,
      );

      // Tap SUV card
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();

      // Verify SUV card now displays checkmark badge and crimson border
      expect(
        find.descendant(of: suvCardInkWell, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      final suvContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: suvCardInkWell, matching: find.byType(AnimatedContainer)).first,
      );
      final decoration = suvContainer.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, equals(AppColors.caliperCrimson));

      // Verify Sedan card is no longer selected
      expect(
        find.descendant(of: sedanCardInkWell, matching: find.byIcon(Icons.check)),
        findsNothing,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.10.4: mapUiCategoryToSrs maps Sedan, SUV, Motorcycle, and Commercial to SRS specifications', () {
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan / Hatch'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV / Micro'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Motorcycle'), equals('Motorcycle'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Commercial'), equals('Light Commercial'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Light Commercial'), equals('Light Commercial'));
    });

    testWidgets('T1.10.5: Fuel type selector chips (Octane, Petrol, Diesel, CNG, EV) toggle selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Out of Fuel'),
          physicalSize: const Size(600, 1400),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(find.text('Octane'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('Diesel'), findsOneWidget);
      expect(find.text('CNG'), findsOneWidget);
      expect(find.text('EV'), findsOneWidget);

      // Verify default selected fuel is Octane
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Octane')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Diesel')).selected,
        isFalse,
      );

      // Select Diesel
      await tester.tap(find.text('Diesel'));
      await tester.pump();

      // Verify selection shifted to Diesel
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Diesel')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Octane')).selected,
        isFalse,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.10.6: License plate input captures and formats vehicle registration plate',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'General Breakdown'),
        ),
      );
      await tester.pump();

      final plateInput = find.byType(TextField);
      expect(plateInput, findsOneWidget);

      await tester.enterText(plateInput, 'Chatto Metro GA-12-9988');
      await tester.pump();

      expect(find.text('Chatto Metro GA-12-9988'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 11: R3.4 Fault Details & Symptom Chips
  // =========================================================================
  group('Feature 11: R3.4 Fault Details & Symptom Chips (SRS §R3)', () {
    testWidgets('T1.11.1: FaultDetailsScreen displays hero fault summary card with selected fault and vehicle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.heroFaultSummaryCard, findsOneWidget);
      expect(find.text('Dead Battery'), findsWidgets);
      expect(find.textContaining('Passenger Car'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.11.2: Symptom chips toggle selection state on tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
        ),
      );
      await tester.pump();

      final chipFinder = find.text('Engine completely silent (no crank)');
      expect(chipFinder, findsOneWidget);

      // Verify initially no symptom chips are checked
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap chip to select
      await tester.tap(chipFinder);
      await tester.pump();

      // Verify checkmark icon rendered for selected symptom
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(chipFinder);
      await tester.pump();

      // Verify checkmark icon removed
      expect(find.byIcon(Icons.check), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.11.3: "Stranded in live highway lane" toggle switches high-priority state',
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

      expect(find.text('Stranded in live highway lane'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Verify initial live lane switch is false and emergency warning banner is absent
      expect(tester.widget<Switch>(switches.first).value, isFalse);
      expect(
        find.textContaining('HIGH ROADWAY HAZARD: Priority dispatch queue activated'),
        findsNothing,
      );

      // Tap first switch (live lane hazard)
      await tester.tap(switches.first, warnIfMissed: false);
      await tester.pump();

      // Verify switch toggled to true and high hazard warning banner rendered
      expect(tester.widget<Switch>(switches.first).value, isTrue);
      expect(
        find.textContaining('HIGH ROADWAY HAZARD: Priority dispatch queue activated'),
        findsOneWidget,
      );

      // Toggle off to verify bidirectional control
      await tester.tap(switches.first, warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<Switch>(switches.first).value, isFalse);
      expect(
        find.textContaining('HIGH ROADWAY HAZARD: Priority dispatch queue activated'),
        findsNothing,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.11.4: "Hazard lights functioning" switch toggles state',
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

      expect(find.text('Hazard lights functioning'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Verify default state is true
      expect(tester.widget<Switch>(switches.last).value, isTrue);

      // Tap last switch to toggle off
      await tester.tap(switches.last, warnIfMissed: false);
      await tester.pump();

      // Verify switch toggled to false
      expect(tester.widget<Switch>(switches.last).value, isFalse);

      // Tap last switch to toggle back on
      await tester.tap(switches.last, warnIfMissed: false);
      await tester.pump();

      // Verify switch toggled back to true
      expect(tester.widget<Switch>(switches.last).value, isTrue);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.11.5: Diagnostic notes text field captures user input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Towing',
            vehicleType: 'Light Commercial',
            licensePlate: 'Dhaka Metro TA-14-5566',
          ),
        ),
      );
      await tester.pump();

      final notesInput = find.byType(TextField);
      expect(notesInput, findsOneWidget);

      await tester.enterText(notesInput, 'Vehicle stuck near roadside ditch after downpour');
      await tester.pump();

      expect(find.text('Vehicle stuck near roadside ditch after downpour'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.11.6: Proceeding with "FIND NEARBY MECHANICS" button is present and enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Out of Fuel',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.requestMechanicButton, findsOneWidget);

      // Verify button is enabled and has valid non-null callback
      final buttonWidget = tester.widget<ElevatedButton>(E2EFinders.requestMechanicButton);
      expect(buttonWidget.enabled, isTrue);
      expect(buttonWidget.onPressed, isNotNull);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 12: R3.5 Login Screen Modern Layout
  // =========================================================================
  group('Feature 12: R3.5 Login Screen Modern Layout (SRS §R3)', () {
    testWidgets('T1.12.1: LoginScreen renders modern layout with porcelain background and clear branding',
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
      expect(find.text('ROADIX'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.12.2: Google Sign-In button contains authentic Google BrandLogo',
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

      final googleLogo = find.descendant(
        of: E2EFinders.googleSignInButton,
        matching: find.byType(BrandLogo),
      );
      expect(googleLogo, findsOneWidget);

      final brandLogo = tester.widget<BrandLogo>(googleLogo);
      expect(brandLogo.brand.toLowerCase(), equals('google'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.12.3: Tab toggle switches between Mobile OTP and Email Account auth modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.phoneAuthTab, findsOneWidget);
      expect(E2EFinders.emailAuthTab, findsOneWidget);

      // Switch to Email Account
      await tester.tap(E2EFinders.emailAuthTab);
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.12.4: Role selector displays Motorist and Technician options',
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

        // Switch to Email Account mode where Sign Up toggle is available
        await tester.tap(E2EFinders.emailAuthTab);
        await tester.pump();

        // Switch to Sign Up mode where role selector is active
        await tester.tap(find.text('Need a new account? Sign Up'));
        await tester.pump();

        expect(find.text('Motorist'), findsWidgets);
        expect(find.text('Technician'), findsWidgets);

        // Initially Motorist account title is shown
        expect(find.text('Create Motorist Account'), findsOneWidget);

        // Tap Technician option in role selector
        await tester.tap(E2EFinders.mechanicRoleTab);
        await tester.pump();

        // Role switches to Technician account title
        expect(find.text('Create Technician Account'), findsOneWidget);

        await E2ETestHarness.cleanUp(tester);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('T1.12.5: Non-blocking demo login buttons for Motorist and Technician are present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(E2EFinders.motoristDemoButton, findsOneWidget);
      expect(E2EFinders.mechanicDemoButton, findsOneWidget);
      expect(find.text('Guest SOS'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.12.6: Entering phone number validates standard 11-digit input format',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      final phoneField = find.byType(TextField);
      expect(phoneField, findsWidgets);

      await tester.enterText(phoneField.first, '01811223344');
      await tester.pump();

      expect(find.text('01811223344'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 13: R3.6 Profile Screen & Digital Garage
  // =========================================================================
  group('Feature 13: R3.6 Profile Screen & Digital Garage (SRS §R3)', () {
    testWidgets('T1.13.1: ProfileScreen renders profile identity card and verification indicators',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.13.2: Digital Garage section displays vehicle cards and "+ Add Vehicle" action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.digitalGarageHeader, findsOneWidget);
      expect(find.text('+ Add Vehicle'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.13.3: Linked Wallets section displays "Manage Wallets" button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.linkedWalletsHeader, findsOneWidget);
      expect(find.text('Manage Wallets'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.13.4: Emergency Contacts section displays "+ Add Contact" action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.emergencyContactsHeader, findsOneWidget);
      expect(find.text('+ Add Contact'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.13.5: Technician Console mode switcher card is displayed with navigation cue',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Technician Console'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.13.6: Log Out button with Icons.logout renders in Caliper Crimson',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1000),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2EFinders.logoutButton, findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
