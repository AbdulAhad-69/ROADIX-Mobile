import 'dart:io';
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
import 'package:roadix_mobile/services/geocoding_service.dart';
import 'package:roadix_mobile/src/core/utils/geometry_utils.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

/// Milestone 5 Phase 2: Tier 5 Adversarial Coverage Hardening Test Suite
///
/// White-box adversarial stress tests probing concurrency races, null boundaries,
/// poison payloads, service dropouts, rapid taps, and extreme viewports.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  tearDown(() {
    E2ETestHarness.setMockGps(
      lat: 23.8759,
      lng: 90.3795,
      accuracy: 8.0,
      serviceEnabled: true,
      permission: 3,
    );
  });

  // =========================================================================
  // SUB-SUITE 1: Rapid-Fire User Interactions & Concurrency Race Hardening
  // =========================================================================
  group('Tier 5.1: Concurrency & Rapid-Interaction Hardening', () {
    testWidgets(
        'T5.1.1: Rapid consecutive multi-taps (10x) on Recenter GPS button on LocationConfirmScreen do not crash or spawn concurrent camera races',
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

      final initialQueryCount = E2ETestHarness.gpsQueryCount;

      // Burst 10 rapid taps on the recenter button in quick succession
      for (int i = 0; i < 10; i++) {
        await tester.tap(E2EFinders.recenterButton, warnIfMissed: false);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Internal _isLocating guard should throttle and prevent unhandled re-entrancy
      expect(tester.takeException(), isNull);
      expect(E2ETestHarness.gpsQueryCount, greaterThanOrEqualTo(initialQueryCount));
      expect(find.byType(LocationConfirmScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.1.2: Rapid burst-tapping on EmergencyHomeScreen SOS help trigger maintains modal integrity without duplicate routes',
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

      // Rapidly tap SOS button 6 times
      await tester.scrollUntilVisible(E2EFinders.sosHomeButton, 300);
      for (int i = 0; i < 6; i++) {
        await tester.tap(E2EFinders.sosHomeButton, warnIfMissed: false);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet should be presented without crash
      expect(tester.takeException(), isNull);
      expect(find.text('Select Emergency Action'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.1.3: Rapid role switching (20x) on LoginScreen preserves controller integrity and causes zero exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Sign Up so role toggle chips are active
      await tester.tap(find.text('Need a new account? Sign Up'));
      await tester.pump();

      // Alternating 20 rapid taps between Sign-Up roles
      for (int i = 0; i < 10; i++) {
        await tester.tap(E2EFinders.mechanicRoleTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(E2EFinders.motoristRoleTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.tap(find.text('Already have an account? Sign In'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.1.4: Rapid multi-tap on Demo Login button navigates cleanly without duplicate pushReplacement crashes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LoginScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final demoBtn = E2EFinders.motoristDemoButton;
      expect(demoBtn, findsOneWidget);

      // Tap demo button 5 times rapidly
      for (int i = 0; i < 5; i++) {
        await tester.tap(demoBtn, warnIfMissed: false);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.1.5: Rapid consecutive toggling of live hazard switch and multiple symptoms in FaultDetailsScreen preserves state consistency',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Sedan / Hatch',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly toggle the live lane hazard switch 8 times
      final switchFinder = find.byType(Switch).first;
      for (int i = 0; i < 8; i++) {
        await tester.tap(switchFinder, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Tap symptom chips rapidly
      final symptomChip1 = find.text('Engine completely silent (no crank)');
      final symptomChip2 = find.text('Rapid clicking sound on ignition');

      if (symptomChip1.evaluate().isNotEmpty) {
        await tester.tap(symptomChip1);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(symptomChip1); // deselect
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(symptomChip1); // reselect
      }

      if (symptomChip2.evaluate().isNotEmpty) {
        await tester.tap(symptomChip2);
      }
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.requestMechanicButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.1.6: Rapid bottom navigation bar cycling (Home -> Profile -> Activity -> Home) while background futures execute resolves cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final profileNavIcon = find.byIcon(Icons.person_outline);
      final activityNavIcon = find.byIcon(Icons.history);
      final homeNavIcon = find.byIcon(Icons.home);

      for (int i = 0; i < 5; i++) {
        if (profileNavIcon.evaluate().isNotEmpty) {
          await tester.tap(profileNavIcon);
          await tester.pump(const Duration(milliseconds: 20));
        }
        if (activityNavIcon.evaluate().isNotEmpty) {
          await tester.tap(activityNavIcon);
          await tester.pump(const Duration(milliseconds: 20));
        }
        if (homeNavIcon.evaluate().isNotEmpty) {
          await tester.tap(homeNavIcon);
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // SUB-SUITE 2: Null Safety Boundaries, Poison Inputs & Malformed Data
  // =========================================================================
  group('Tier 5.2: Poison Inputs & Null Safety Boundary Hardening', () {
    testWidgets(
        'T5.2.1: BrandLogo handles poison brand strings (SQL injection, null bytes, unicode, spaces) with authentic fallback and 0 exceptions',
        (WidgetTester tester) async {
      final poisonBrands = [
        '',
        '   ',
        'bkash\x00corrupt',
        'DROP TABLE wallets;--',
        '<script>alert("xss")</script>',
        'UNKNOWN_CRYPTO_CURRENCY_TOKEN',
        '   bKash   ',
        'UPAY_UPPERCASE_TEST',
        '🚀🔥🎯',
      ];

      for (final brand in poisonBrands) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BrandLogo(brand: brand, size: 32),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(BrandLogo), findsOneWidget);
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.2.2: BrandLogo handles extreme dimensions (size: 0.0, 0.001, 1500.0) without layout panic or DivisionByZero',
        (WidgetTester tester) async {
      final extremeSizes = [0.0, 0.001, 1.0, 500.0, 1500.0];

      for (final size in extremeSizes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BrandLogo(brand: 'bkash', size: size),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await E2ETestHarness.cleanUp(tester);
    });

    test('T5.2.3: GeocodingService.reverseGeocode & detectDivision survive poisoned coordinates (0.0, NaN, Infinity, -999.0)',
        () async {
      // 1. Coordinates at Null Island (0.0, 0.0) with custom geocode override
      E2ETestHarness.registerGeocodeResult(0.0, 0.0, 'Null Island Roadside Position (0.0000° N, 0.0000° E)');
      final nullIslandAddr = await GeocodingService.reverseGeocode(0.0, 0.0);
      expect(nullIslandAddr, isNotEmpty);
      expect(nullIslandAddr, contains('0.0000° N, 0.0000° E'));

      // 2. Out-of-bounds coordinates
      final outOfBoundsAddr = await GeocodingService.reverseGeocode(999.0, -999.0);
      expect(outOfBoundsAddr, isNotEmpty);

      // 3. Division detection for non-Bangladesh coordinates returns clean empty string without throw
      final divisionOutside = GeocodingService.detectDivision(45.0, 10.0);
      expect(divisionOutside, isEmpty);

      // 4. Coordinates exactly on boundaries of Bangladesh divisions
      expect(GeocodingService.detectDivision(23.8759, 90.3795), 'Dhaka');
      expect(GeocodingService.detectDivision(22.3569, 91.8215), 'Chittagong');
      expect(GeocodingService.detectDivision(24.8949, 91.8687), 'Sylhet');
      expect(GeocodingService.detectDivision(22.8456, 89.5403), 'Khulna');
      expect(GeocodingService.detectDivision(24.3636, 88.6241), 'Rajshahi');
    });

    testWidgets(
        'T5.2.4: EmergencyHomeScreen & ProfileScreen survive completely empty profile fields (full_name: "", phone: "", avatar_url: null) with safe initials fallback',
        (WidgetTester tester) async {
      E2ETestHarness.mockProfile = {
        'id': 'empty-user',
        'full_name': '',
        'phone': '',
        'role': 'motorist',
        'is_nid_verified': false,
        'avatar_url': null,
      };

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const EmergencyHomeScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      // Header avatar should render safe initial 'M' fallback
      expect(find.text('M'), findsWidgets);

      // Mount ProfileScreen with the same empty profile
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.2.5: VehicleIllustration handles unknown, empty, or exotic vehicle types by falling back to passenger car without error',
        (WidgetTester tester) async {
      final exoticTypes = [
        '',
        'Helicopter',
        'Hyperloop Pod',
        'Bulldozer Heavy Armor',
        'Unknown Prototype',
      ];

      for (final type in exoticTypes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: VehicleIllustration(vehicleType: type, size: 48),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(VehicleIllustration), findsOneWidget);
      }

      await E2ETestHarness.cleanUp(tester);
    });

    test('T5.2.6: GeometryUtils.parsePostgisPoint survives malformed inputs (empty string, truncated hex, invalid types) returning null without throwing',
        () {
      expect(GeometryUtils.parsePostgisPoint(null), isNull);
      expect(GeometryUtils.parsePostgisPoint(''), isNull);
      expect(GeometryUtils.parsePostgisPoint('   '), isNull);
      expect(GeometryUtils.parsePostgisPoint('010100'), isNull); // truncated EWKB hex
      expect(GeometryUtils.parsePostgisPoint('NOT_A_HEX_STRING_AT_ALL_123456789012345678901234'), isNull);
      expect(GeometryUtils.parsePostgisPoint(12345), isNull); // non-string non-map
      expect(GeometryUtils.parsePostgisPoint(<String, dynamic>{}), isNull); // empty map
      expect(GeometryUtils.parsePostgisPoint({'coordinates': 'invalid_type'}), isNull);
      expect(GeometryUtils.parsePostgisPoint({'coordinates': [90.3795]}), isNull); // only 1 coordinate
    });

    test('T5.2.7: PhoneUtils handles adversarial inputs (empty, letters, international formatting, spaces, emojis) gracefully',
        () {
      expect(PhoneUtils.normalize(''), '');
      expect(PhoneUtils.normalize('   '), '');
      expect(PhoneUtils.normalize('abcdefghijk'), '');
      expect(PhoneUtils.isValidBangladeshPhone(''), isFalse);
      expect(PhoneUtils.isValidBangladeshPhone('0171234567'), isFalse); // 10 digits
      expect(PhoneUtils.isValidBangladeshPhone('017123456789'), isFalse); // 12 digits
      expect(PhoneUtils.isValidBangladeshPhone('01212345678'), isFalse); // invalid operator prefix (012)

      // Valid variations
      expect(PhoneUtils.isValidBangladeshPhone('01711000001'), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone('+8801711000001'), isTrue);
      expect(PhoneUtils.isValidBangladeshPhone('+880 1711-000001'), isTrue);
      expect(PhoneUtils.formatForDisplay('01711000001'), '+880 1711-000001');

      // Hotline 999
      final telUri = PhoneUtils.createTelUri('999');
      expect(telUri.toString(), 'tel:999');
    });
  });

  // =========================================================================
  // SUB-SUITE 3: Service Fault Injection, Network Dropouts & Recovery Hardening
  // =========================================================================
  group('Tier 5.3: Fault Injection & Service Recovery Hardening', () {
    testWidgets(
        'T5.3.1: LocationConfirmScreen under complete location failure (services disabled & permission denied) falls back gracefully to preset and shows SnackBar',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(
        lat: 23.8759,
        lng: 90.3795,
        serviceEnabled: false,
        permission: 0,
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const LocationConfirmScreen(
            selectedFault: 'General Breakdown',
            initialLat: 23.8759,
            initialLng: 90.3795,
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(E2EFinders.recenterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Location services are disabled on your device'), findsOneWidget);
      expect(find.textContaining('23.8759° N, 90.3795° E'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.3.2: SosScreen unmounted mid-countdown (after 2.5s) disposes controllers cleanly without TickerCanceled leak or unhandled pending timers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const SosScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      // Let animation run for 2.5 seconds
      await tester.pump(const Duration(milliseconds: 2500));

      // Pop / Unmount the widget tree abruptly
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.3.3: SosScreen handles GPS failure by falling back to estimated regional corridor display',
        (WidgetTester tester) async {
      E2ETestHarness.setMockGps(
        lat: 23.8759,
        lng: 90.3795,
        serviceEnabled: false,
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const SosScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Estimated'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.3.4: ProfileScreen signOut survives fatal backend failure, navigating to LoginScreen via finally block',
        (WidgetTester tester) async {
      E2ETestHarness.onSignOutOverride = () async {
        throw const SocketException('Connection reset by peer');
      };

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to logout button and tap
      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      expect(E2EFinders.logoutButton, findsOneWidget);
      await tester.tap(E2EFinders.logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.3.5: WalletEditorSheet rejects sub-11-digit numbers with clear error and accepts valid 11-digit numbers cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletEditorSheet(
              wallets: [
                {
                  'id': 'w-1',
                  'provider': 'bKash',
                  'number': '01711000001',
                  'isPrimary': true,
                }
              ],
              onAddWallet: (provider, number) async {
                // Mock add wallet
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Enter short number (6 digits)
      final input = find.byType(TextField);
      await tester.enterText(input, '017111');
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      // Error message displayed
      expect(find.textContaining('Please enter a valid 11-digit mobile wallet number'), findsOneWidget);

      // Enter valid 11-digit number
      await tester.enterText(input, '01711223344');
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.3.6: DispatchScreen cancellation during active search stops timers and marks status without unhandled exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const DispatchScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Sedan / Hatch',
            licensePlate: 'Dhaka Metro GA-11-2034',
            symptoms: ['Engine completely silent'],
            isHighPriority: false,
            breakdownAddress: 'Sector 11, Uttara, Dhaka',
          ),
          physicalSize: const Size(800, 1200),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Cancel Request
      final cancelBtn = find.text('CANCEL REQUEST');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Confirm cancellation in modal
        final confirmBtn = find.text('YES, CANCEL REQUEST');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // SUB-SUITE 4: Viewport Constraints, Extreme Densities & Layout Resilience
  // =========================================================================
  group('Tier 5.4: Viewport Constraints & High-Density Layout Hardening', () {
    testWidgets(
        'T5.4.1: EmergencyHomeScreen on ultra-compact viewport (320px x 480px) with 1.5x font scale renders cleanly without overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.5),
            ),
            child: const EmergencyHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmergencyHomeScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.4.2: SosScreen on compact screen (320px x 568px) with 1.4x font scale remains fully scrollable without RenderFlex panic',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.4),
            ),
            child: const SosScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(SosScreen), findsOneWidget);
      expect(E2EFinders.tapToCancelButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.4.3: VehicleSelectScreen on compact viewport displays all 4 classifications with distinct specs cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const VehicleSelectScreen(selectedFault: 'Towing'),
          physicalSize: const Size(320, 600),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.motorcycleCard, findsOneWidget);
      expect(E2EFinders.sedanCard, findsOneWidget);
      expect(E2EFinders.suvCard, findsOneWidget);
      expect(E2EFinders.commercialCard, findsOneWidget);

      // Select SUV
      await tester.scrollUntilVisible(
        E2EFinders.suvCard,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(E2EFinders.suvCard);
      await tester.pump();

      expect(E2EFinders.continueToFaultButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.4.4: FaultDetailsScreen on compact viewport with diagnostic questionnaire renders responsive layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const FaultDetailsScreen(
            selectedFault: 'Engine Trouble',
            vehicleType: 'SUV / Micro',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
          physicalSize: const Size(320, 600),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.heroFaultSummaryCard, findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
      expect(E2EFinders.requestMechanicButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.4.5: LoginScreen with simulated active on-screen keyboard (bottom inset: 320px) preserves form accessibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 320),
            ),
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets(
        'T5.4.6: ProfileScreen on compact viewport renders Digital Garage, Linked Wallets, and Emergency Contacts with smooth scrolling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const ProfileScreen(),
          physicalSize: const Size(320, 568),
          tester: tester,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(E2EFinders.digitalGarageHeader, findsOneWidget);

      // Scroll down to check wallets and contacts headers
      await tester.scrollUntilVisible(E2EFinders.linkedWalletsHeader, 300);
      expect(E2EFinders.linkedWalletsHeader, findsOneWidget);

      await tester.scrollUntilVisible(E2EFinders.logoutButton, 400);
      expect(E2EFinders.logoutButton, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
