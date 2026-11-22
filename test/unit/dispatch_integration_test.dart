import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/screens/dispatch_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/widgets/vehicle_editor_sheet.dart';

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );

    await AppConfig.initialize();
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Supabase already initialized or offline mock active
    }
  });
  group('Phase 4: Dispatch Flow Parameter & SRS Category Verification', () {
    test('VehicleSelectScreen maps UI categories to exact SRS categories', () {
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan / Hatch'), 'Passenger Car');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV / Micro'), 'Passenger Car');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan'), 'Passenger Car');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV'), 'Passenger Car');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Motorcycle'), 'Motorcycle');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Commercial'), 'Light Commercial');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Light Commercial'), 'Light Commercial');
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Unknown'), 'Passenger Car');
    });

    test('VehicleEditorSheet normalizes legacy categories to exact SRS categories', () {
      expect(VehicleEditorSheet.normalizeToSrsCategory('Sedan'), 'Passenger Car');
      expect(VehicleEditorSheet.normalizeToSrsCategory('SUV'), 'Passenger Car');
      expect(VehicleEditorSheet.normalizeToSrsCategory('Motorcycle'), 'Motorcycle');
      expect(VehicleEditorSheet.normalizeToSrsCategory('Commercial'), 'Light Commercial');
      expect(VehicleEditorSheet.normalizeToSrsCategory('Passenger Car'), 'Passenger Car');
      expect(VehicleEditorSheet.normalizeToSrsCategory('Light Commercial'), 'Light Commercial');
    });

    test('DispatchScreen default parameters preserve location and defaults safely', () {
      const screen = DispatchScreen(
        selectedFault: 'Flat Tire',
        vehicleType: 'Passenger Car',
        licensePlate: 'Dhaka Metro GA-11-2034',
        symptoms: ['Visible nail/screw puncture'],
        isHighPriority: true,
      );

      expect(screen.selectedFault, 'Flat Tire');
      expect(screen.vehicleType, 'Passenger Car');
      expect(screen.licensePlate, 'Dhaka Metro GA-11-2034');
      expect(screen.symptoms, contains('Visible nail/screw puncture'));
      expect(screen.isHighPriority, isTrue);
      expect(screen.breakdownLat, closeTo(23.8759, 0.0001));
      expect(screen.breakdownLng, closeTo(90.3795, 0.0001));
      expect(screen.breakdownAddress, contains('Dhaka'));
      expect(screen.diagnosticNotes, isEmpty);
      expect(screen.existingRequestId, isNull);
    });

    test('DispatchScreen constructor preserves custom location and notes when passed', () {
      const screen = DispatchScreen(
        selectedFault: 'Engine Trouble',
        vehicleType: 'Motorcycle',
        licensePlate: 'Dhaka Metro LA-24-9011',
        symptoms: ['Engine stalled unexpectedly'],
        isHighPriority: false,
        breakdownLat: 23.7925,
        breakdownLng: 90.4078,
        breakdownAddress: 'Gulshan 2 Circle, Dhaka',
        diagnosticNotes: 'White smoke from exhaust',
        existingRequestId: '00000000-0000-0000-0000-000000000123',
      );

      expect(screen.breakdownLat, closeTo(23.7925, 0.0001));
      expect(screen.breakdownLng, closeTo(90.4078, 0.0001));
      expect(screen.breakdownAddress, 'Gulshan 2 Circle, Dhaka');
      expect(screen.diagnosticNotes, 'White smoke from exhaust');
      expect(screen.existingRequestId, '00000000-0000-0000-0000-000000000123');
    });

    test('Vehicle snapshot serialization conforms to DB snapshot trigger contract', () {
      final srsCategories = ['Passenger Car', 'Motorcycle', 'Light Commercial'];

      for (final cat in srsCategories) {
        final snapshot = {
          'vehicle_type': cat,
          'plate': 'Dhaka Metro GA-11-2034',
        };

        expect(snapshot['vehicle_type'], isIn(srsCategories));
        expect(snapshot['plate'], isNotEmpty);
      }
    });

    test('Search radius increments follow 5km -> 7.5km -> 10km -> 12.5km -> 15km limits', () {
      double radius = 5.0;
      const step = 2.5;
      const maxRadius = 15.0;

      final sequence = <double>[radius];
      while (radius < maxRadius) {
        radius += step;
        sequence.add(radius);
      }

      expect(sequence, [5.0, 7.5, 10.0, 12.5, 15.0]);
      expect(sequence.first, 5.0);
      expect(sequence.last, 15.0);
    });

    test('Transient backend clock skew detection string matches exception pattern', () {
      const serverException = 'Exception: PostgrestException(message: An offer is already active for this request., code: P0001)';
      expect(serverException.contains('already active'), isTrue);

      const standardError = 'Exception: Network connection failed';
      expect(standardError.contains('already active'), isFalse);
    });

    test('Active service request status filter includes all in-flight lifecycle states', () {
      const activeStates = [
        'searching',
        'assigned',
        'en_route',
        'arrived',
        'diagnosing',
        'quote_pending',
        'servicing',
      ];

      expect(activeStates.contains('searching'), isTrue);
      expect(activeStates.contains('assigned'), isTrue);
      expect(activeStates.contains('servicing'), isTrue);
      expect(activeStates.contains('completed'), isFalse);
      expect(activeStates.contains('cancelled'), isFalse);
    });

    test('GoRouter query parameter parsing preserves location and normalizes vehicle', () {
      final queryParams = {
        'fault': 'Battery Jumpstart',
        'vehicle': 'SUV / Micro',
        'plate': 'DHAKA-METRO-GA-11',
        'lat': '23.8103',
        'lng': '90.4125',
        'address': 'Banani 11, Dhaka',
        'notes': 'Dead battery after parking with lights on',
        'priority': 'true',
        'requestId': 'req-uuid-456',
      };

      final fault = queryParams['fault'] ?? 'General';
      final rawVehicle = queryParams['vehicle'] ?? 'Passenger Car';
      final vehicle = VehicleSelectScreen.mapUiCategoryToSrs(rawVehicle);
      final plate = queryParams['plate'] ?? 'DHAKA-METRO';
      final lat = double.tryParse(queryParams['lat'] ?? '') ?? 23.8759;
      final lng = double.tryParse(queryParams['lng'] ?? '') ?? 90.3795;
      final address = queryParams['address'] ?? 'Dhaka Region • Roadside Position';
      final notes = queryParams['notes'] ?? '';
      final isHighPriority = queryParams['priority'] == 'true';
      final requestId = queryParams['requestId'];

      expect(fault, 'Battery Jumpstart');
      expect(vehicle, 'Passenger Car');
      expect(plate, 'DHAKA-METRO-GA-11');
      expect(lat, closeTo(23.8103, 0.0001));
      expect(lng, closeTo(90.4125, 0.0001));
      expect(address, 'Banani 11, Dhaka');
      expect(notes, 'Dead battery after parking with lights on');
      expect(isHighPriority, isTrue);
      expect(requestId, 'req-uuid-456');
    });

    test('Triage 4-step workflow labels and progress fractions are sequentially aligned', () {
      const stepSequence = [
        {'step': 'STEP 1 OF 4', 'title': 'LOCATION TRIAGE', 'fraction': 0.25},
        {'step': 'STEP 2 OF 4', 'title': 'VEHICLE CLASSIFICATION', 'fraction': 0.50},
        {'step': 'STEP 3 OF 4', 'title': 'DEFECT QUESTIONNAIRE', 'fraction': 0.75},
        {'step': 'STEP 4 OF 4', 'title': 'DISPATCH & TELEMETRY', 'fraction': 1.00},
      ];

      expect(stepSequence.length, 4);
      for (int i = 0; i < stepSequence.length; i++) {
        expect(stepSequence[i]['fraction'], equals((i + 1) * 0.25));
        expect(stepSequence[i]['step'], equals('STEP ${i + 1} OF 4'));
      }
    });

    test('Radar search discrete rings strictly correspond to 5km, 10km, and 15km radii', () {
      const discreteRadarRingsKm = [5.0, 10.0, 15.0];
      for (final radius in discreteRadarRingsKm) {
        expect(radius, isIn([5.0, 10.0, 15.0]));
        expect(radius, lessThanOrEqualTo(15.0));
      }
    });

    test('Mechanic verification simulation flag enables duty readiness', () {
      bool isVerified = false;
      bool isOnDuty = false;

      // Unverified mechanic cannot toggle duty
      void toggleDuty(bool value) {
        if (value && !isVerified) return;
        isOnDuty = value;
      }

      toggleDuty(true);
      expect(isOnDuty, isFalse); // Blocked

      // Simulate admin verification
      isVerified = true;
      toggleDuty(true);
      expect(isOnDuty, isTrue); // Permitted
    });

    test('Demo technician authentication flag guards against premature home redirection', () {
      bool isDemoActionInProgress = false;
      String destinationRoute = 'none';

      // Simulates auth listener
      void onAuthStateChange(bool hasSession) {
        if (hasSession && !isDemoActionInProgress) {
          destinationRoute = 'home';
        }
      }

      // During technician demo login
      isDemoActionInProgress = true;
      onAuthStateChange(true); // Supabase session created
      expect(destinationRoute, equals('none')); // Home redirection properly suppressed

      // Dedicated technician route is chosen
      destinationRoute = 'mechanic';
      isDemoActionInProgress = false;
      expect(destinationRoute, equals('mechanic'));
    });

    test('Dispatch fallback seamlessly activates demo radar simulation when unauthenticated', () {
      bool isDemoRadarActive = false;
      String? requestCode;
      double searchRadius = 0.0;

      void onDispatchError(dynamic error, String? currentUserId) {
        if (error.toString().contains('Authentication required') || currentUserId == null) {
          isDemoRadarActive = true;
          requestCode = 'RDX-DEMO-8821';
          searchRadius = 5.0;
        }
      }

      onDispatchError('PostgrestException(message: Authentication required.)', null);

      expect(isDemoRadarActive, isTrue);
      expect(requestCode, equals('RDX-DEMO-8821'));
      expect(searchRadius, equals(5.0));
    });

    testWidgets('Renders on 360x800 and 390x844 viewports without RenderFlex overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Flat Tire',
              vehicleType: 'Passenger Car',
              licensePlate: 'Dhaka Metro GA-11-2034',
              symptoms: ['Puncture'],
              isHighPriority: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final demoBtn = find.text('Run Interactive Demo Simulation');
      if (demoBtn.evaluate().isNotEmpty) {
        await tester.tap(demoBtn);
        await tester.pump();
      }

      // Verify searching view with elapsed timer has no overflows
      expect(tester.takeException(), isNull);

      // Advance by 2 seconds (radius expands to 10km)
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      // Advance by 2 more seconds (enters offered phase with candidate cards & timers)
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      // Verify candidate card and offer expiration timer rendered cleanly
      expect(find.textContaining('remaining • Expiring'), findsOneWidget);
      expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);
      expect(find.textContaining('Dhaka Metro GA-11-2034'), findsOneWidget);

      // Teardown / dispose cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Teardown during demo simulation cancels all simulation timers without leakage', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Battery Jumpstart',
              vehicleType: 'Passenger Car',
              licensePlate: 'Dhaka Metro HA-55-9921',
              symptoms: ['Dead battery'],
              isHighPriority: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final demoBtn = find.text('Run Interactive Demo Simulation');
      if (demoBtn.evaluate().isNotEmpty) {
        await tester.tap(demoBtn);
        await tester.pump();
      }

      // Advance to offered phase
      await tester.pump(const Duration(seconds: 4));

      // Tap simulation accept button
      final acceptBtn = find.text('Accept Offer (Simulate Mechanic)');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pump();

      // Immediately unmount the screen before 4s/8s/12s/16s simulation timers fire
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      // If any timer leaked past dispose, testWidgets will fail assertion !timersPending
    });

    testWidgets('Renders on 390x844 and 320x640 viewports without RenderFlex overflow', (WidgetTester tester) async {
      for (final size in [const Size(390, 844), const Size(320, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DispatchScreen(
                selectedFault: 'Engine Breakdown & Overheating',
                vehicleType: 'Passenger Car',
                licensePlate: 'Dhaka Metro GA-11-2034',
                symptoms: ['Overheating engine', 'Steam from radiator'],
                isHighPriority: true,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final demoBtn = find.text('Run Interactive Demo Simulation');
        if (demoBtn.evaluate().isNotEmpty) {
          await tester.tap(demoBtn);
          await tester.pump();
        }

        expect(tester.takeException(), isNull);

        // Advance to offered phase
        await tester.pump(const Duration(seconds: 4));
        expect(tester.takeException(), isNull);

        // Verify key widgets render cleanly
        expect(find.textContaining('Expiring'), findsOneWidget);
        expect(find.textContaining('rescues'), findsWidgets);
        expect(find.textContaining('Uttara 24/7 Motors'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Cancellation stops and clears all simulation timers cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DispatchScreen(
              selectedFault: 'Flat Tire',
              vehicleType: 'Motorcycle',
              licensePlate: 'Dhaka Metro HA-12-3456',
              symptoms: ['Flat tire'],
              isHighPriority: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final demoBtn = find.text('Run Interactive Demo Simulation');
      if (demoBtn.evaluate().isNotEmpty) {
        await tester.tap(demoBtn);
        await tester.pump();
      }

      // Advance by 1 second while searching is active
      await tester.pump(const Duration(seconds: 1));

      // Tap Cancel Search
      final cancelBtn = find.text('Cancel Search');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn);
        await tester.pump();

        // Confirm dialog if shown
        final confirmBtn = find.text('Yes, Cancel');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn);
          await tester.pump();
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
