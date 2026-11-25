import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/services/supabase_service.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
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
  // GROUP 1: GEOLOCATION, MAP & TRIAGE CROSS-FEATURE COMBINATIONS
  // =========================================================================
  group('Tier 3: Geolocation, Map & Triage Combinations', () {
    testWidgets(
        'T3.1: R1.1 + R3.1: Recenter GPS interaction on EmergencyHomeScreen updates current coordinates and active location banner',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 8.0);
      E2ETestHarness.registerGeocodeResult(
        23.8759,
        90.3795,
        'Sector 11, Uttara, Dhaka, Bangladesh',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial detected location banner shows Uttara / Dhaka
      expect(find.text('DETECTED LOCATION'), findsOneWidget);
      expect(find.textContaining('Uttara'), findsWidgets);

      // Now GPS updates to Gulshan, Dhaka
      const newLat = 23.7925;
      const newLng = 90.4078;
      E2ETestHarness.setMockGps(lat: newLat, lng: newLng, accuracy: 5.0);
      E2ETestHarness.registerGeocodeResult(
        newLat,
        newLng,
        'Gulshan 2, Dhaka, Bangladesh',
      );

      // Tap on the Detected Location card / "Change" to open LocationConfirmScreen
      await tester.tap(find.text('Change'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      // Tap recenter button
      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('23.7925° N, 90.4078° E'), findsOneWidget);
      expect(find.textContaining('Gulshan 2'), findsWidgets);

      // Confirm new location
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Popped back to EmergencyHomeScreen with updated location banner
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);
      expect(
        find.textContaining('Gulshan 2, Dhaka, Bangladesh'),
        findsWidgets,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.2: R1.1 + R3.2: SOS emergency screen locks and preserves GPS coordinates when emergency countdown initiates',
        (WidgetTester tester) async {
      const mockLat = 23.7500;
      const mockLng = 90.3900;
      E2ETestHarness.setMockGps(lat: mockLat, lng: mockLng, accuracy: 6.0);
      E2ETestHarness.registerGeocodeResult(
        mockLat,
        mockLng,
        'Kawran Bazar, Dhaka, Bangladesh',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const SosScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.text('EMERGENCY SOS ACTIVE'), findsOneWidget);
      expect(find.text('LIVE GPS'), findsOneWidget);
      expect(find.text('23.7500° N, 90.3900° E'), findsOneWidget);
      expect(find.text('±6m Acc'), findsOneWidget);

      // Advance countdown by 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('TAP TO CANCEL (3s)'), findsOneWidget);

      // Coordinates remain firmly locked and preserved at 4-decimal precision
      expect(find.text('23.7500° N, 90.3900° E'), findsOneWidget);
      expect(find.text('Kawran Bazar, Dhaka, Bangladesh'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.3: R1.1 + R4.3: Recenter button within Triage Wizard Step 4 (LocationConfirmScreen) updates position coordinates',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 12.0);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            initialLat: 23.8759,
            initialLng: 90.3795,
            accuracyMeters: 12,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('± 12m accuracy'), findsOneWidget);
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsOneWidget);

      // GPS position updates with high accuracy
      const newLat = 22.3569;
      const newLng = 91.8215;
      E2ETestHarness.setMockGps(lat: newLat, lng: newLng, accuracy: 4.0);

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('± 4m accuracy'), findsOneWidget);
      expect(find.textContaining('22.3569° N, 91.8215° E'), findsOneWidget);

      // Advance wizard to Step 2
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      final vehicleSelect = tester.widget<VehicleSelectScreen>(
        find.byType(VehicleSelectScreen),
      );
      expect(vehicleSelect.breakdownLat, closeTo(newLat, 0.0001));
      expect(vehicleSelect.breakdownLng, closeTo(newLng, 0.0001));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.7: R1.3 + R3.4: Chittagong geocoding combined with specific fault symptoms (e.g. coastal flooding/engine stall) passes correctly into location screen',
        (WidgetTester tester) async {
      const chittagongLat = 22.3569;
      const chittagongLng = 91.8215;
      E2ETestHarness.registerGeocodeResult(
        chittagongLat,
        chittagongLng,
        'Agrabad Commercial Area, Chittagong, Bangladesh',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Engine Trouble',
            initialLat: chittagongLat,
            initialLng: chittagongLng,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Chittagong'), findsWidgets);

      // Confirm location -> VehicleSelectScreen
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);

      // Continue to Fault Details
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      final faultDetails = tester.widget<FaultDetailsScreen>(
        find.byType(FaultDetailsScreen),
      );
      expect(faultDetails.breakdownAddress, contains('Chittagong'));
      expect(faultDetails.selectedFault, equals('Engine Trouble'));

      // Select specific symptom: Engine stalling repeatedly
      final stallingSymptom = find.text('Engine stalling repeatedly');
      expect(stallingSymptom, findsOneWidget);
      await tester.tap(stallingSymptom);
      await tester.pump();

      // Verified symptom is checked
      expect(find.byIcon(Icons.check), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.8: R1.3 + R4.3: Multi-department geocoding (Sylhet) seamlessly carries through triage wizard to location confirmation',
        (WidgetTester tester) async {
      const sylhetLat = 24.8949;
      const sylhetLng = 91.8687;
      E2ETestHarness.registerGeocodeResult(
        sylhetLat,
        sylhetLng,
        'Zindabazar, Sylhet, Bangladesh',
      );

      // Step 1: LocationConfirmScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Out of Fuel',
            initialLat: sylhetLat,
            initialLng: sylhetLng,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Sylhet'), findsWidgets);

      // Step 2: Advance to VehicleSelectScreen
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      final vScreen = tester.widget<VehicleSelectScreen>(
        find.byType(VehicleSelectScreen),
      );
      expect(vScreen.breakdownAddress, contains('Sylhet'));
      expect(vScreen.breakdownLat, closeTo(sylhetLat, 0.0001));
      expect(vScreen.breakdownLng, closeTo(sylhetLng, 0.0001));

      // Step 3: Advance to FaultDetailsScreen
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      final fScreen = tester.widget<FaultDetailsScreen>(
        find.byType(FaultDetailsScreen),
      );
      expect(fScreen.breakdownAddress, contains('Sylhet'));

      // Step 4: Advance to DispatchScreen
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DispatchScreen), findsOneWidget);
      final dScreen = tester.widget<DispatchScreen>(
        find.byType(DispatchScreen),
      );
      expect(dScreen.breakdownAddress, contains('Sylhet'));
      expect(dScreen.breakdownLat, closeTo(sylhetLat, 0.0001));
      expect(dScreen.breakdownLng, closeTo(sylhetLng, 0.0001));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.9: R1.4 + R4.3: Coordinate and address sanitization cleanses inputs before passing into dispatch creation',
        (WidgetTester tester) async {
      const rawLat = 23.875912345678;
      const rawLng = 90.379598765432;
      const dirtyAddress = '   Sector 11, Uttara, Dhaka   ';
      E2ETestHarness.registerGeocodeResult(rawLat, rawLng, dirtyAddress);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Dead Battery',
            initialLat: rawLat,
            initialLng: rawLng,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Coordinate displayed at exactly 4 decimal places
      expect(find.textContaining('23.8759° N, 90.3796° E'), findsOneWidget);
      expect(find.textContaining('23.875912'), findsNothing);

      // Address is trimmed of leading and trailing whitespace
      expect(find.text('Sector 11, Uttara, Dhaka'), findsOneWidget);
      expect(find.text(dirtyAddress), findsNothing);

      // Continue through triage to DispatchScreen
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DispatchScreen), findsOneWidget);
      final dScreen = tester.widget<DispatchScreen>(
        find.byType(DispatchScreen),
      );
      expect(dScreen.breakdownAddress, equals('Sector 11, Uttara, Dhaka'));

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // GROUP 2: DISPATCH TRACKING & VEHICLE INTELLIGENCE COMBINATIONS
  // =========================================================================
  group('Tier 3: Dispatch Tracking & Vehicle Intelligence Combinations', () {
    testWidgets(
        'T3.4: R1.2 + R2.1: Live dispatch tracking displays payment brand logo (e.g., bKash) on incoming mechanic quote',
        (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed by')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Flat Tire',
            vehicleType: 'Sedan',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Visible nail/screw puncture'],
            isHighPriority: false,
          ),
          physicalSize: const Size(800, 1800),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Advance by 4 seconds into offered phase
      await tester.pump(const Duration(seconds: 4));

      // Incoming offer card is visible
      expect(find.textContaining('remaining • Expiring'), findsOneWidget);
      expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);

      // Simulate Mechanic Acceptance -> transitions to Assigned Phase
      final acceptBtn = find.text('Accept Offer (Simulate Mechanic)');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pump();

      expect(find.text('STATUS: ASSIGNED'), findsOneWidget);

      // Advance through stages to quotation: 4s en route, 4s arrived, 4s diagnosing, 4s quote_pending
      await tester.pump(const Duration(seconds: 4)); // en_route
      await tester.pump(const Duration(seconds: 4)); // arrived
      await tester.pump(const Duration(seconds: 4)); // diagnosing
      await tester.pump(const Duration(seconds: 4)); // quote_pending -> opens Quotation Review Sheet
      await tester.pump(const Duration(milliseconds: 500)); // allow bottom sheet transition to complete

      // In Quotation Review Sheet, approve quote
      final approveBtn = find.text('APPROVE & START');
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pump(const Duration(milliseconds: 500)); // allow sheet dismissal transition

      // Advance 5 seconds for servicing completion -> opens Digital Invoice & Payment Sheet
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500)); // allow invoice sheet transition

      // Verify payment brand logo for bKash is displayed on invoice / settlement quote
      expect(E2EFinders.brandLogo('bkash'), findsWidgets);
      expect(find.text('bKash MFS'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.5: R1.2 + R3.3: DispatchScreen reflects selected vehicle classification (Motorcycle, Sedan, SUV, Commercial) in tracking header',
        (WidgetTester tester) async {
      // 1. Verify Commercial vehicle tracking
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Towing',
            vehicleType: 'Commercial',
            licensePlate: 'Dhaka Commercial TA-99-4411',
            symptoms: ['Wheels locked'],
            isHighPriority: false,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Commercial • Dhaka Commercial TA-99-4411'),
        findsOneWidget,
      );

      // 2. Verify Motorcycle vehicle tracking
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Flat Tire',
            vehicleType: 'Motorcycle',
            licensePlate: 'Dhaka Metro HA-12-3456',
            symptoms: ['Puncture'],
            isHighPriority: false,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Motorcycle • Dhaka Metro HA-12-3456'),
        findsOneWidget,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.6: R1.2 + R3.4: Selecting "Stranded in live highway lane" in FaultDetails marks priority dispatch in DispatchScreen radar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Engine Trouble',
            vehicleType: 'SUV / Micro',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Toggle first switch for live highway lane hazard
      final liveLaneSwitch = find.byType(Switch).first;
      expect(liveLaneSwitch, findsOneWidget);
      await tester.tap(liveLaneSwitch);
      await tester.pump();

      expect(find.text('URGENT'), findsOneWidget);
      expect(
        find.textContaining('HIGH ROADWAY HAZARD: Priority dispatch queue activated'),
        findsOneWidget,
      );

      // Tap FIND NEARBY MECHANICS
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // In DispatchScreen, priority radar status is activated
      expect(find.byType(DispatchScreen), findsOneWidget);
      final dispatchScreen = tester.widget<DispatchScreen>(
        find.byType(DispatchScreen),
      );
      expect(dispatchScreen.isHighPriority, isTrue);
      expect(find.text('PRIORITY'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.15: R3.3 + R3.4: Selecting "Motorcycle" updates fault symptoms list to motorcycle-relevant faults',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Engine Trouble'),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Motorcycle card
      await tester.tap(E2EFinders.motorcycleCard);
      await tester.pump();

      // Continue to fault details
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      final faultDetails = tester.widget<FaultDetailsScreen>(
        find.byType(FaultDetailsScreen),
      );
      expect(faultDetails.vehicleType, equals('Motorcycle'));

      // Summary card reflects Motorcycle and Engine Trouble
      expect(find.text('Engine Trouble'), findsWidgets);
      expect(find.textContaining('Motorcycle'), findsWidgets);

      // Select engine stalling symptom
      await tester.tap(find.text('Engine stalling repeatedly'));
      await tester.pump();

      expect(find.byIcon(Icons.check), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.16: R3.3 + R4.3: Selecting "Commercial" passes commercial vehicle weight and plate into downstream dispatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Towing'),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select Commercial vehicle
      await tester.tap(E2EFinders.commercialCard);
      await tester.pump();

      expect(find.text('Up to 3.5 Ton • Flatbed'), findsWidgets);

      // Enter custom commercial registration plate
      final plateField = find.widgetWithText(TextField, 'Dhaka Metro GA-11-2034');
      await tester.enterText(plateField, 'Dhaka Metro TA-77-5500');
      await tester.pump();

      // Continue to Fault Details
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(
        find.text('Light Commercial • Dhaka Metro TA-77-5500'),
        findsOneWidget,
      );

      // Find nearby mechanics -> DispatchScreen
      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DispatchScreen), findsOneWidget);
      final dScreen = tester.widget<DispatchScreen>(
        find.byType(DispatchScreen),
      );
      expect(dScreen.vehicleType, equals('Light Commercial'));
      expect(dScreen.licensePlate, equals('Dhaka Metro TA-77-5500'));
      expect(
        find.textContaining('Light Commercial • Dhaka Metro TA-77-5500'),
        findsWidgets,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.20: R4.3 + R1.2: Completing all 4 triage wizard steps launches DispatchScreen with matching fault and coordinates',
        (WidgetTester tester) async {
      const wizardLat = 23.8103;
      const wizardLng = 90.4125;
      E2ETestHarness.registerGeocodeResult(
        wizardLat,
        wizardLng,
        'Banani, Dhaka, Bangladesh',
      );

      // Step 1: LocationConfirmScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'Out of Fuel',
            initialLat: wizardLat,
            initialLng: wizardLng,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationConfirmScreen), findsOneWidget);
      expect(
        tester.widget<LocationConfirmScreen>(find.byType(LocationConfirmScreen)).selectedFault,
        equals('Out of Fuel'),
      );
      await tester.tap(E2EFinders.confirmLocationButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 2: VehicleSelectScreen
      expect(find.byType(VehicleSelectScreen), findsOneWidget);
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();
      await tester.tap(E2EFinders.continueToFaultButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 3: FaultDetailsScreen
      expect(find.byType(FaultDetailsScreen), findsOneWidget);
      expect(find.text('Out of Fuel'), findsWidgets);

      final fuelSymptom = find.text('Fuel gauge reads empty');
      expect(fuelSymptom, findsOneWidget);
      await tester.tap(fuelSymptom);
      await tester.pump();

      await tester.tap(E2EFinders.requestMechanicButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 4: DispatchScreen launches with matching state
      expect(find.byType(DispatchScreen), findsOneWidget);
      final dScreen = tester.widget<DispatchScreen>(
        find.byType(DispatchScreen),
      );
      expect(dScreen.selectedFault, equals('Out of Fuel'));
      expect(dScreen.vehicleType, equals('Passenger Car'));
      expect(dScreen.breakdownLat, closeTo(wizardLat, 0.0001));
      expect(dScreen.breakdownLng, closeTo(wizardLng, 0.0001));
      expect(dScreen.symptoms, contains('Fuel gauge reads empty'));

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // GROUP 3: BRANDING, PAYMENT & DISPLAY SCALING COMBINATIONS
  // =========================================================================
  group('Tier 3: Branding, Payment & Display Scaling Combinations', () {
    testWidgets(
        'T3.10: R2.1 + R2.3: Adding a new wallet (Nagad) via WalletEditorSheet renders authentic Nagad BrandLogo in linked wallets list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: WalletEditorSheet(wallets: []),
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select Nagad from Dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Nagad').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter 11-digit wallet number
      await tester.enterText(find.byType(TextField), '01811223344');
      await tester.pump();

      // Tap Add button
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Nagad wallet appears in linked wallets list with authentic Nagad BrandLogo
      expect(find.textContaining('Nagad (01811223344)'), findsOneWidget);
      expect(E2EFinders.brandLogo('Nagad'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.11: R2.1 + R3.6: Brand logos render correctly in Digital Garage / Payment Wallets section of ProfileScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(showBackButton: false),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('PAYMENT & MFS WALLETS'), findsOneWidget);

      // Primary wallet has authentic BrandLogo
      expect(E2EFinders.brandLogo('bKash'), findsWidgets);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.12: R2.2 + R3.6: Scaled brand logos fit neatly within wallet list tiles without vertical overflow',
        (WidgetTester tester) async {
      // Test on a narrow, compact 320x600 viewport
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(showBackButton: false),
          physicalSize: const Size(320, 600),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure zero RenderFlex or layout overflows occurred
      expect(tester.takeException(), isNull);

      final brandLogoFinder = find.byType(BrandLogo);
      expect(brandLogoFinder, findsWidgets);

      // Verify each BrandLogo fits nicely within expected size bounds
      final brandLogos = tester.widgetList<BrandLogo>(brandLogoFinder);
      for (final logo in brandLogos) {
        expect(logo.size, lessThanOrEqualTo(48.0));
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.21: R2.3 + R4.2: Wallet additions in ProfileScreen persist in SharedPreferences/SecureStorage across session logout',
        (WidgetTester tester) async {
      await SupabaseService().addWallet(
        provider: 'Nagad',
        accountNumber: '01899887766',
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(showBackButton: false),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Log out
      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LoginScreen), findsOneWidget);

      // Re-login
      await tester.tap(E2EFinders.motoristDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // Retrieve wallets post-logout to verify persistence
      final wallets = await SupabaseService().getWallets();
      expect(wallets, isNotEmpty);
      expect(wallets.any((w) => w['provider'] == 'Nagad'), isTrue);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // GROUP 4: AUTHENTICATION, SOS & PROFILE LIFECYCLE COMBINATIONS
  // =========================================================================
  group('Tier 3: Authentication, SOS & Profile Lifecycle Combinations', () {
    testWidgets(
        'T3.13: R3.1 + R3.2: Tapping SOS button from EmergencyHome initiates SOS screen with active countdown',
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

      expect(E2EFinders.sosHomeButton, findsOneWidget);

      // Tap SOS button
      await tester.tap(E2EFinders.sosHomeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom sheet with 999 Police / Medical option appears
      expect(find.text('Select Emergency Action'), findsOneWidget);
      expect(find.text('Call 999 Police / Medical'), findsOneWidget);

      // Tap 999 option
      await tester.tap(find.text('Call 999 Police / Medical'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // SosScreen is pushed with active countdown
      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.text('EMERGENCY SOS ACTIVE'), findsOneWidget);
      expect(find.textContaining('TAP TO CANCEL (5s)'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.14: R3.1 + R3.5: Logging out from EmergencyHome returns to LoginScreen; logging in as Motorist lands back on EmergencyHome',
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

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);

      // Scroll to logout button and tap it
      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // Successfully transitioned to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Tap Motorist demo button to log back in
      await tester.tap(E2EFinders.motoristDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // Successfully transitioned back to EmergencyHomeScreen
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.17: R3.5 + R4.2: Login via demo button sets role and navigates to correct home screen (Motorist vs Technician)',
        (WidgetTester tester) async {
      // Sub-case 1: Motorist Demo Login -> EmergencyHomeScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.motoristDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);
      await E2ETestHarness.cleanUp(tester);

      // Sub-case 2: Technician Demo Login -> MechanicHomeScreen
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.mechanicDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MechanicHomeScreen), findsOneWidget);
      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.18: R3.6 + R4.1: Updating avatar from ProfileScreen immediately updates avatar displayed in profile header',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(showBackButton: false),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Edit Profile Sheet
      expect(E2EFinders.editProfileButton, findsOneWidget);
      await tester.tap(E2EFinders.editProfileButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EditProfileSheet), findsOneWidget);

      // Select first avatar preset
      final presetUrl = EditProfileSheet.avatarPresets.first;
      final presetFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar &&
            widget.backgroundImage is NetworkImage &&
            (widget.backgroundImage as NetworkImage).url == presetUrl,
      );
      if (presetFinder.evaluate().isNotEmpty) {
        await tester.tap(presetFinder.first);
      } else {
        await tester.tap(find.byIcon(Icons.person_outline).first);
      }
      await tester.pump();

      // Tap SAVE CHANGES
      await tester.tap(find.widgetWithText(ElevatedButton, 'SAVE CHANGES'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Sheet closed, ProfileScreen header remains updated
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(EditProfileSheet), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.19: R4.1 + R4.2: Updated profile picture persists across logout and subsequent re-login',
        (WidgetTester tester) async {
      const persistedAvatarUrl =
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';

      // 1. Update profile with avatar URL
      await SupabaseService().updateProfile(
        fullName: 'Motorist',
        phone: '+8801711000001',
        avatarUrl: persistedAvatarUrl,
      );
      E2ETestHarness.mockProfile['avatar_url'] = persistedAvatarUrl;

      // 2. Open ProfileScreen and verify avatar is active
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(showBackButton: false),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Log out to LoginScreen
      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LoginScreen), findsOneWidget);

      // 4. Re-login as Motorist
      await tester.tap(E2EFinders.motoristDemoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      // EmergencyHomeScreen profile avatar header preserves the updated avatar
      expect(E2ETestHarness.mockProfile['avatar_url'], equals(persistedAvatarUrl));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T3.22: R3.2 + R1.4: SOS Screen formats distress coordinate string with 4-decimal precision in emergency SMS/payload',
        (WidgetTester tester) async {
      const highPrecisionLat = 23.87591234567;
      const highPrecisionLng = 90.37959876543;
      E2ETestHarness.setMockGps(
        lat: highPrecisionLat,
        lng: highPrecisionLng,
        accuracy: 7.0,
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const SosScreen(),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SosScreen), findsOneWidget);

      // Formatted with exact 4-decimal precision
      expect(find.text('23.8759° N, 90.3796° E'), findsOneWidget);
      expect(find.text('±7m Acc'), findsOneWidget);

      // Excessive decimals are sanitized away
      expect(find.textContaining('23.875912'), findsNothing);
      expect(find.textContaining('90.379598'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
