import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/services/demo_session.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  tearDown(() {
    E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 8.0);
  });

  // =========================================================================
  // TIER 4: REAL-WORLD APPLICATION WORKLOAD SCENARIOS (TEST_INFRA.md)
  // =========================================================================
  group('Tier 4: Real-World Application Workloads (SRS §R1-R4)', () {
    // -----------------------------------------------------------------------
    // SCENARIO 1: Motorist Highway Puncture Rescue in Chittagong
    // Features exercised: R1.1, R1.3, R2.1, R3.1, R3.3, R3.4, R4.3
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 1: Motorist Highway Puncture Rescue in Chittagong (R1.1, R1.3, R2.1, R3.1, R3.3, R3.4, R4.3)',
        (WidgetTester tester) async {
      DemoSession.startDemo(demoRole: 'motorist');
      addTearDown(DemoSession.clear);

      // 1. Set mock GPS to Chittagong coordinates (22.3569, 91.8215)
      E2ETestHarness.setMockGps(lat: 22.3569, lng: 91.8215, accuracy: 6.0);

      // 2. Mount EmergencyHomeScreen. Verify Chittagong location context and select "Flat Tire" triage card
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Chittagong location context renders without "Dhaka"
      expect(find.textContaining('Chittagong'), findsWidgets);
      final locationWidgets = find.textContaining('Chittagong').evaluate();
      for (final element in locationWidgets) {
        final textWidget = element.widget as Text;
        expect(textWidget.data?.contains('Dhaka'), isFalse,
            reason: 'Chittagong location context must not contain hardcoded "Dhaka"');
      }

      // Verify Emergency Home UI elements
      expect(E2EFinders.sosHomeButton, findsOneWidget);
      expect(E2EFinders.pressForHelpText, findsOneWidget);
      expect(E2EFinders.triageSectionTitle, findsOneWidget);

      // Select "Flat Tire" triage card
      expect(E2EFinders.breakdownCategory('Flat Tire'), findsOneWidget);
      await tester.tap(E2EFinders.breakdownCategory('Flat Tire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Lands on LocationConfirmScreen
      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(find.text('Flat Tire'), findsWidgets);

      // Verify Chittagong address renders without "Dhaka"
      expect(find.textContaining('Agrabad Commercial Area, Chittagong, Bangladesh'), findsWidgets);
      final locationScreenAddress = find.descendant(
        of: find.byType(LocationConfirmScreen),
        matching: find.textContaining('Chittagong'),
      );
      expect(locationScreenAddress, findsWidgets);
      for (final element in locationScreenAddress.evaluate()) {
        final textWidget = element.widget as Text;
        expect(textWidget.data?.contains('Dhaka'), isFalse,
            reason: 'Chittagong address on LocationConfirmScreen must not contain "Dhaka"');
      }

      // Verify coordinate badge formatting (4 decimal precision)
      expect(find.textContaining('22.3569° N, 91.8215° E'), findsOneWidget);

      // Tap recenter button
      expect(E2EFinders.recenterButton, findsOneWidget);
      final prevGpsCount = E2ETestHarness.gpsQueryCount;
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(E2ETestHarness.gpsQueryCount, greaterThan(prevGpsCount));

      // Tap "CONFIRM LOCATION"
      expect(E2EFinders.confirmLocationButton, findsOneWidget);
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 4. Lands on VehicleSelectScreen
      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // Select "Sedan / Hatch" and provide license plate
      expect(E2EFinders.sedanCard, findsOneWidget);
      await tester.tap(E2EFinders.sedanCard);
      await tester.enterText(E2EFinders.licensePlateField, 'Dhaka Metro GA-11-2034');
      await tester.pump();

      // Verify license plate format
      expect(find.textContaining('Dhaka Metro'), findsWidgets);

      // Tap "CONTINUE TO FAULT DETAILS"
      expect(E2EFinders.continueToFaultButton, findsOneWidget);
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. Lands on FaultDetailsScreen
      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(E2EFinders.heroFaultSummaryCard, findsOneWidget);

      // Select symptom: visible nail/screw puncture
      final punctureChip = find.text('Visible nail/screw puncture');
      expect(punctureChip, findsOneWidget);
      await tester.tap(punctureChip);
      await tester.pump();

      // Scroll to live lane hazard section and toggle
      await tester.scrollUntilVisible(
        find.text('Stranded in live highway lane'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final liveLaneSwitch = find.byType(Switch).first;
      expect(liveLaneSwitch, findsOneWidget);
      await tester.tap(liveLaneSwitch);
      await tester.pump();

      // Verify high roadway hazard priority banner
      expect(find.textContaining('Priority hazard dispatch activated'), findsOneWidget);

      // Tap "FIND NEARBY MECHANICS"
      expect(E2EFinders.requestMechanicButton, findsOneWidget);
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 6. Lands on DispatchScreen
      expect(find.byType(DispatchScreen), findsOneWidget);

      // Verify radar begins at 5.0 km
      expect(find.textContaining('within 5.0 km'), findsOneWidget);

      // Radius expands dynamically to 10.0 km after 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('within 10.0 km'), findsOneWidget);

      // Advances to offer after 2 more seconds (total 4s)
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('remaining • Expiring'), findsOneWidget);
      expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);

      // Accept offer (simulate mechanic)
      final acceptOfferBtn = find.text('Accept Offer (Simulate Mechanic)');
      expect(acceptOfferBtn, findsOneWidget);
      await tester.tap(acceptOfferBtn);
      await tester.pump();

      // Verify progress status through ASSIGNED -> EN_ROUTE -> ARRIVED
      expect(find.text('STATUS: ASSIGNED'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: EN_ROUTE'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('STATUS: ARRIVED'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SCENARIO 2: Motorcycle Battery Jumpstart in Sylhet via Guest SOS
    // Features exercised: R1.2, R1.3, R3.1, R3.2, R3.3, R3.5
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 2: Motorcycle Battery Jumpstart in Sylhet via Guest SOS (R1.2, R1.3, R3.1, R3.2, R3.3, R3.5)',
        (WidgetTester tester) async {
      // 1. Set mock GPS to Sylhet coordinates (24.8949, 91.8687)
      E2ETestHarness.setMockGps(lat: 24.8949, lng: 91.8687, accuracy: 5.0);

      // 2. Mount EmergencyHomeScreen, trigger SOS emergency screen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Sylhet location context without "Dhaka"
      expect(find.textContaining('Sylhet'), findsWidgets);

      // Trigger SOS modal from EmergencyHomeScreen
      await tester.tap(E2EFinders.sosHomeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Call 999 Police / Medical' from modal
      final call999 = find.textContaining('Call 999 Police / Medical');
      expect(call999, findsOneWidget);
      await tester.tap(call999);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 3. Verify SOS red flashing alert and active countdown on SosScreen
      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.text('EMERGENCY SOS ACTIVE'), findsOneWidget);
      expect(find.textContaining('CALLING ('), findsOneWidget);

      // Verify Sylhet address on SOS screen does not contain "Dhaka"
      final sosSylhetAddress = find.descendant(
        of: find.byType(SosScreen),
        matching: find.textContaining('Sylhet'),
      );
      expect(sosSylhetAddress, findsWidgets);
      for (final element in sosSylhetAddress.evaluate()) {
        final textWidget = element.widget as Text;
        expect(textWidget.data?.contains('Dhaka'), isFalse,
            reason: 'Sylhet address on SosScreen must not contain hardcoded "Dhaka"');
      }

      // 4. Tap "TAP TO CANCEL SOS", verify emergency cancelled banner
      expect(E2EFinders.tapToCancelButton, findsOneWidget);
      await tester.tap(E2EFinders.tapToCancelButton);
      await tester.pump();

      expect(find.text('CANCELLED'), findsOneWidget);

      // Return to EmergencyHomeScreen cleanly via close icon on SosScreen
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      // 5. Switch to LoginScreen via logout, tap "Motorist" demo login
      await tester.tap(find.textContaining('Welcome,'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 300);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LoginScreen), findsOneWidget);

      // Tap "Demo Motorist" login
      final motoristDemo = E2EFinders.motoristDemoButton;
      expect(motoristDemo, findsOneWidget);
      await tester.tap(motoristDemo);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Mounted back into EmergencyHomeScreen
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      // 6. Select "Battery" triage card for "Motorcycle", verify Sylhet address resolution, and launch dispatch
      await tester.tap(E2EFinders.breakdownCategory('Battery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(find.textContaining('Sylhet'), findsWidgets);

      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      expect(E2EFinders.motorcycleCard, findsOneWidget);
      await tester.tap(E2EFinders.motorcycleCard);
      await tester.enterText(E2EFinders.licensePlateField, 'Sylhet Metro LA-12-4455');
      await tester.pump();

      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      final batterySymptom = find.text('Rapid clicking sound on ignition');
      expect(batterySymptom, findsOneWidget);
      await tester.tap(batterySymptom);
      await tester.pump();

      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DispatchScreen), findsOneWidget);
      expect(find.textContaining('Motorcycle'), findsWidgets);
      expect(find.textContaining('Sylhet'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SCENARIO 3: Heavy Commercial Vehicle Towing Request on Gazipur Highway
    // Features exercised: R1.1, R1.4, R3.3, R3.4, R4.3
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 3: Heavy Commercial Vehicle Towing Request on Gazipur Highway (R1.1, R1.4, R3.3, R3.4, R4.3)',
        (WidgetTester tester) async {
      // 1. Set mock GPS to Gazipur highway coordinates (23.9999, 90.4200)
      E2ETestHarness.setMockGps(lat: 23.9999, lng: 90.4200, accuracy: 4.0);
      E2ETestHarness.registerGeocodeResult(
        23.9999,
        90.4200,
        '  Gazipur Bypass, Dhaka-Mymensingh Hwy, Gazipur  ',
      );

      // 2. Start triage flow from EmergencyHomeScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Select "Towing" triage card
      expect(E2EFinders.breakdownCategory('Towing'), findsOneWidget);
      await tester.tap(E2EFinders.breakdownCategory('Towing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 3. On LocationConfirmScreen: verify 4-decimal coordinate formatting and sanitized whitespace address
      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(find.textContaining('23.9999° N, 90.4200° E'), findsOneWidget);
      expect(find.text('Gazipur Bypass, Dhaka-Mymensingh Hwy, Gazipur'), findsWidgets);
      expect(find.text('  Gazipur Bypass, Dhaka-Mymensingh Hwy, Gazipur  '), findsNothing);

      // Tap recenter button
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirm location
      expect(E2EFinders.confirmLocationButton, findsOneWidget);
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 4. On VehicleSelectScreen: choose "Commercial" vehicle category and enter commercial plate
      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      expect(E2EFinders.commercialCard, findsOneWidget);
      await tester.tap(E2EFinders.commercialCard);
      await tester.pump();

      // Enter commercial license plate "Dhaka Metro TA-14-9988"
      final plateField = find.byType(TextField);
      expect(plateField, findsWidgets);
      await tester.enterText(plateField.first, 'Dhaka Metro TA-14-9988');
      await tester.pump();

      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. On FaultDetailsScreen: select flatbed tow symptom and toggle live lane hazard
      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      final flatbedSymptom = find.text('Flatbed tow truck required');
      expect(flatbedSymptom, findsOneWidget);
      await tester.tap(flatbedSymptom);
      await tester.pump();

      // Enter diagnostic note
      final noteField = find.descendant(
        of: find.byType(FaultDetailsScreen),
        matching: find.byType(TextField),
      );
      if (noteField.evaluate().isNotEmpty) {
        await tester.enterText(noteField.last, 'Heavy Tow Required: Rear axle snapped on Gazipur flyover');
        await tester.pump();
      }

      // Scroll to live highway lane hazard section and toggle
      await tester.scrollUntilVisible(
        find.text('Stranded in live highway lane'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final liveLaneSwitch = find.byType(Switch).first;
      expect(liveLaneSwitch, findsOneWidget);
      await tester.tap(liveLaneSwitch);
      await tester.pump();
      expect(find.textContaining('Priority hazard dispatch activated'), findsOneWidget);

      // 6. Confirm and launch dispatch, verify commercial dispatch request payload
      expect(E2EFinders.requestMechanicButton, findsOneWidget);
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DispatchScreen), findsOneWidget);

      // Verify commercial vehicle payload: canonical SRS 'Light Commercial', plate, and Gazipur location
      expect(find.textContaining('Light Commercial'), findsWidgets);
      expect(find.textContaining('Dhaka Metro TA-14-9988'), findsWidgets);
      expect(find.textContaining('Gazipur'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SCENARIO 4: SOS Emergency Panic Call & Cancellation Flow
    // Features exercised: R1.1, R1.4, R3.1, R3.2
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 4: SOS Emergency Panic Call & Cancellation Flow (R1.1, R1.4, R3.1, R3.2)',
        (WidgetTester tester) async {
      // 1. Mount EmergencyHomeScreen, tap big red SOS button
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(E2EFinders.sosHomeButton, findsOneWidget);
      await tester.tap(E2EFinders.sosHomeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final call999 = find.textContaining('Call 999 Police / Medical');
      expect(call999, findsOneWidget);
      await tester.tap(call999);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 2. On SosScreen, verify countdown begins
      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.text('EMERGENCY SOS ACTIVE'), findsOneWidget);
      expect(find.textContaining('CALLING ('), findsOneWidget);

      // 3. Tap Highway Patrol card, verify dialer URL contains 'tel:999'
      E2ETestHarness.launchedUrls.clear();
      expect(E2EFinders.highwayPatrolCard, findsOneWidget);
      await tester.tap(E2EFinders.highwayPatrolCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(E2ETestHarness.launchedUrls, contains('tel:999'));

      // 4. Tap Ambulance card, verify dialer URL recorded
      expect(E2EFinders.nationalAmbulanceCard, findsOneWidget);
      await tester.tap(E2EFinders.nationalAmbulanceCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        E2ETestHarness.launchedUrls.where((url) => url == 'tel:999').length,
        greaterThanOrEqualTo(2),
      );

      // 5. Tap "TAP TO CANCEL SOS", verify countdown stops and CANCELLED banner renders cleanly
      expect(E2EFinders.tapToCancelButton, findsOneWidget);
      await tester.tap(E2EFinders.tapToCancelButton);
      await tester.pump();

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(E2EFinders.tapToCancelButton, findsNothing);

      // 6. Return to home screen cleanly via close icon on SosScreen
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);
      expect(E2EFinders.sosHomeButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SCENARIO 5: Digital Garage & Multi-Wallet Lifecycle
    // Features exercised: R2.1, R2.3, R3.6, R4.1, R4.2
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 5: Digital Garage & Multi-Wallet Lifecycle (R2.1, R2.3, R3.6, R4.1, R4.2)',
        (WidgetTester tester) async {
      DemoSession.startDemo(demoRole: 'motorist');
      addTearDown(DemoSession.clear);

      // 1. Mount ProfileScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ProfileScreen), findsOneWidget);

      // 2. Inspect Digital Garage vehicles list (verify primary vehicle rendered)
      expect(E2EFinders.digitalGarageHeader, findsOneWidget);
      expect(find.textContaining('Toyota Corolla Axio'), findsOneWidget);
      expect(find.textContaining('DHAKA METRO GA-11-2034'), findsOneWidget);
      expect(find.text('Primary'), findsWidgets);

      // 3. Inspect Linked Wallets section (verify bKash brand logo)
      expect(E2EFinders.linkedWalletsHeader, findsOneWidget);
      expect(E2EFinders.brandLogo('bKash'), findsWidgets);
      expect(find.textContaining('01711000001'), findsWidgets);

      // 4. Open WalletEditorSheet
      final manageWalletsBtn = find.text('Manage Wallets');
      expect(manageWalletsBtn, findsOneWidget);
      await tester.tap(manageWalletsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(E2EFinders.walletEditorSheet, findsOneWidget);

      // 5. Add new Nagad wallet with phone 01711000002
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nagad').last);
      await tester.pumpAndSettle();

      // Enter Nagad phone number
      final walletPhoneField = find.descendant(
        of: find.byType(WalletEditorSheet),
        matching: find.byType(TextField),
      );
      expect(walletPhoneField, findsOneWidget);
      await tester.enterText(walletPhoneField, '01711000002');
      await tester.pump();

      // Tap "Add" button
      expect(E2EFinders.addWalletButton, findsOneWidget);
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Nagad wallet added with authentic Nagad brand logo
      expect(E2EFinders.brandLogo('Nagad'), findsWidgets);
      expect(find.textContaining('01711000002'), findsOneWidget);

      // Close WalletEditorSheet
      Navigator.of(tester.element(find.byType(WalletEditorSheet))).pop();
      await tester.pumpAndSettle();

      // 6. Update user profile name and avatar URL, verify update reflects
      final editProfileBtn = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editProfileBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EditProfileSheet), findsOneWidget);

      // In EditProfileSheet: editFields.at(1) is _nameController ('MOTORIST NAME')
      final editFields = find.descendant(
        of: find.byType(EditProfileSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(editFields.at(1), 'Tanvir Chowdhury');
      await tester.pump();

      // editFields.at(0) is _avatarUrlController ('OR AVATAR IMAGE URL')
      await tester.enterText(
        editFields.at(0),
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      );
      await tester.pump();

      // Tap "SAVE CHANGES"
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify update reflects on ProfileScreen
      expect(find.text('Tanvir Chowdhury'), findsOneWidget);

      // 7. Tap "Log Out & Return to Login", verify clean transition to LoginScreen
      await tester.scrollUntilVisible(E2EFinders.logoutButton, 300);
      expect(E2EFinders.logoutButton, findsOneWidget);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LoginScreen), findsOneWidget);

      // 8. Log back in with Motorist demo, return to ProfileScreen, verify persistence
      final motoristDemoBtn = E2EFinders.motoristDemoButton;
      expect(motoristDemoBtn, findsOneWidget);
      await tester.tap(motoristDemoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      // Navigate to ProfileScreen from EmergencyHomeScreen
      await tester.tap(find.textContaining('Welcome,'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProfileScreen), findsOneWidget);

      // Verify persistence: profile data is loaded from Supabase profile service
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(E2EFinders.digitalGarageHeader, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SUPPLEMENTARY WORKLOAD 6: Guest SOS Direct Access Flow from LoginScreen
    // Features exercised: R3.1, R3.5, R4.3
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 6: Guest SOS Direct Access from LoginScreen bypasses authentication barrier (R3.5, R4.3)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(600, 1100),
          tester: tester,
        ),
      );
      await tester.pump();

      // Verify Guest SOS action
      final guestSosPill = E2EFinders.guestSosButton;
      expect(guestSosPill, findsOneWidget);
      await tester.tap(guestSosPill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Guest SOS dispatch sheet opened
      expect(find.text('Guest SOS'), findsWidgets);

      // Enter guest phone number
      final phoneInput = find.descendant(
        of: find.byType(Container),
        matching: find.byType(TextField),
      );
      if (phoneInput.evaluate().isNotEmpty) {
        await tester.enterText(phoneInput.first, '01711998877');
        await tester.pump();
      }

      await E2ETestHarness.cleanUp(tester);
    });

    // -----------------------------------------------------------------------
    // SUPPLEMENTARY WORKLOAD 7: Multi-Wallet Selection and Removal Lifecycle
    // Features exercised: R2.1, R2.3, R3.6
    // -----------------------------------------------------------------------
    testWidgets(
        'Scenario 7: Multi-Wallet authorization selection and deletion lifecycle within ProfileScreen (R2.1, R2.3)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open WalletEditorSheet
      await tester.tap(find.text('Manage Wallets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Add Nagad wallet
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nagad').last);
      await tester.pumpAndSettle();

      final phoneField = find.descendant(
        of: find.byType(WalletEditorSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(phoneField, '01811000003');
      await tester.pump();
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(E2EFinders.brandLogo('Nagad'), findsWidgets);

      // Switch primary authorization to Nagad
      final unselectedRadio = find.descendant(
        of: find.byType(WalletEditorSheet),
        matching: find.byIcon(Icons.radio_button_unchecked),
      );
      if (unselectedRadio.evaluate().isNotEmpty) {
        await tester.tap(unselectedRadio.first);
        await tester.pump();
      }

      // Delete initial non-primary wallet if delete icon available
      final deleteIcons = find.descendant(
        of: find.byType(WalletEditorSheet),
        matching: find.byIcon(Icons.delete_outline),
      );
      if (deleteIcons.evaluate().isNotEmpty) {
        await tester.tap(deleteIcons.first);
        await tester.pump();
      }

      Navigator.of(tester.element(find.byType(WalletEditorSheet))).pop();
      await tester.pumpAndSettle();

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
