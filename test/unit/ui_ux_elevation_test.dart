import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/splash_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/services/cloudinary_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import 'package:roadix_mobile/widgets/contact_editor_sheet.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';
import 'package:roadix_mobile/widgets/notifications_bottom_sheet.dart';
import 'package:roadix_mobile/widgets/search_bottom_sheet.dart';
import 'package:roadix_mobile/widgets/vehicle_editor_sheet.dart';
import 'package:roadix_mobile/widgets/vehicle_illustration.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Milestone 3: App-Wide UI/UX Elevation & Responsive Viewports', () {
    testWidgets('EmergencyHomeScreen renders across 320px–412px viewports without RenderFlex overflow', (WidgetTester tester) async {
      final viewports = [
        const Size(320, 568),
        const Size(360, 800),
        const Size(390, 844),
        const Size(412, 915),
      ];

      for (final viewport in viewports) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: EmergencyHomeScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        expect(find.text('SOS'), findsOneWidget);
        expect(find.text('TAP FOR HELP'), findsOneWidget);
        expect(find.text('What do you need help with?'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);
        expect(find.text('Flat Tire'), findsOneWidget);
        expect(find.text('Engine'), findsOneWidget);
        expect(find.text('Out of Fuel'), findsOneWidget);
        expect(find.text('Towing'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('MechanicHomeScreen renders on 320px viewport and stream onError is resilient', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: MechanicHomeScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ROADIX Partner Workshop'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('VehicleSelectScreen renders on 320px viewport without RenderFlex overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: VehicleSelectScreen(
            selectedFault: 'Dead Battery',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Vehicle Classification'), findsOneWidget);
      expect(find.text('Which vehicle needs assistance?'), findsOneWidget);
      expect(find.text('Propulsion / Fuel Type'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('FaultDetailsScreen renders on 320px viewport with hazard toggles without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: FaultDetailsScreen(
            selectedFault: 'Engine Overheating',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Fault Diagnostics'), findsOneWidget);
      expect(find.text('Stranded in live highway lane'), findsOneWidget);
      expect(find.text('Hazard lights functioning'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('SosScreen renders on 320px viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: SosScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Object? sosError = tester.takeException();
      expect(sosError, isNull);
      expect(find.text('999'), findsOneWidget);
      expect(find.text('CALL HIGHWAY PATROL'), findsOneWidget);
      expect(find.text('CALL AMBULANCE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('SplashScreen renders without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ROADIX'), findsOneWidget);
      expect(find.text("HELP WHEN THE ROAD DOESN'T."), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('All bottom sheets render on 320px width without RenderFlex overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      // 1. WalletEditorSheet
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
                },
                {
                  'id': 'w-2',
                  'provider': 'Nagad',
                  'number': '01811000002',
                  'isPrimary': false,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Payment & MFS Wallets'), findsOneWidget);

      // 2. ContactEditorSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactEditorSheet(
              initialContact: const {
                'id': 'c-1',
                'name': 'Mom',
                'phone': '+8801711000002',
                'relation': 'Family',
              },
              onSave: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Emergency Contact'), findsOneWidget);

      // 3. VehicleEditorSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleEditorSheet(
              initialVehicle: const {
                'model': 'Toyota Corolla Cross Hybrid',
                'plate': 'Dhaka Metro GA-11-2034',
                'type': 'Passenger Car',
                'fuel': 'Octane',
              },
              onSave: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Vehicle'), findsOneWidget);

      // 4. NotificationsBottomSheet
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationsBottomSheet(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Notifications & Updates'), findsOneWidget);

      // 5. SearchBottomSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBottomSheet(
              currentLat: 23.8759,
              currentLng: 90.3795,
              onFacilitySelected: (name, lat, lng) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Find Roadside Service'), findsOneWidget);

      // 6. EditProfileSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileSheet(
              currentName: 'Tanvir Ahmed Chowdhury',
              currentPhone: '+8801711000001',
              onProfileSaved: (name, phone) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Profile Details'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('Milestone 4: Key Screen Redesign & Visual Polish Verification (R3)', () {
    test('VehicleIllustration differentiates SUV from Sedan in asset mapping', () {
      final suvAsset = CloudinaryService.getLocalAssetFallback('SUV');
      final sedanAsset = CloudinaryService.getLocalAssetFallback('Sedan');
      final carAsset = CloudinaryService.getLocalAssetFallback('Passenger Car');

      expect(suvAsset, equals('assets/images/suv.png'));
      expect(sedanAsset, equals('assets/images/sedan.png'));
      expect(carAsset, equals('assets/images/sedan.png'));
      expect(suvAsset, isNot(equals(sedanAsset)));
    });

    testWidgets('VehicleIllustration renders distinct SUV and Sedan widgets', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VehicleIllustration(vehicleType: 'SUV', size: 40),
                VehicleIllustration(vehicleType: 'Sedan', size: 40),
                VehicleSpecBadge(label: 'High Clearance • 4x4', isSelected: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(VehicleIllustration), findsNWidgets(2));
      expect(find.byType(VehicleSpecBadge), findsOneWidget);
      expect(find.text('High Clearance • 4x4'), findsOneWidget);
    });

    testWidgets('EmergencyHomeScreen renders 2-row category layout with readable typography', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('Flat Tire'), findsOneWidget);
      expect(find.text('Engine'), findsOneWidget);
      expect(find.text('Out of Fuel'), findsOneWidget);
      expect(find.text('Towing'), findsOneWidget);
      expect(find.text('Other Issue'), findsOneWidget);

      // Verify category title has fontSize >= 12.0
      final titleWidget = tester.widget<Text>(find.text('Battery'));
      expect(titleWidget.style?.fontSize, greaterThanOrEqualTo(12.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('SosScreen displays distinct Highway Patrol and Ambulance emergency cards with badges', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: SosScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CALL HIGHWAY PATROL'), findsOneWidget);
      expect(find.text('POLICE 999'), findsOneWidget);
      expect(find.text('CALL AMBULANCE'), findsOneWidget);
      expect(find.text('MEDICAL 999'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('FaultDetailsScreen renders hero summary card and urgent live highway lane styling', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'Passenger Car',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fault Diagnostics'), findsOneWidget);
      expect(find.text('Dead Battery'), findsWidgets);
      expect(find.textContaining('Passenger Car'), findsOneWidget);
      expect(find.textContaining('Dhaka Metro GA-11-2034'), findsOneWidget);

      // Toggle live highway lane switch to active
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
      await tester.tap(switches.first);
      await tester.pump();

      expect(
        find.textContaining('Priority hazard dispatch activated'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('LoginScreen renders premium Google sign-in button with authentic BrandLogo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      final googleButton = find.widgetWithText(OutlinedButton, 'Continue with Google');
      expect(googleButton, findsOneWidget);

      final brandLogoFinder = find.descendant(
        of: googleButton,
        matching: find.byType(BrandLogo),
      );
      expect(brandLogoFinder, findsOneWidget);

      final brandLogoWidget = tester.widget<BrandLogo>(brandLogoFinder);
      expect(brandLogoWidget.brand.toLowerCase(), equals('google'));
      expect(brandLogoWidget.size, greaterThanOrEqualTo(20.0));

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('ProfileScreen renders elevated identity card and vehicle items with VehicleIllustration', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.textContaining('Digital Garage'), findsOneWidget);
      expect(find.text('Payment Wallets'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('VehicleSelectScreen renders 2x2 grid with VehicleIllustration and selects SUV card cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: VehicleSelectScreen(selectedFault: 'Dead Battery'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VehicleIllustration), findsWidgets);
      expect(find.text('7-Seater / 4x4 Jeep'), findsOneWidget);
      expect(find.text('2-Wheeler / Scooter'), findsOneWidget);
      expect(find.text('Private Passenger Car'), findsOneWidget);
      expect(find.text('Pickup / Covered Van'), findsOneWidget);

      // Tap on SUV card
      await tester.tap(find.text('SUV / Micro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('EmergencyHomeScreen interactive profile header avatar and modernized location card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header avatar is present
      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.textContaining('Welcome,'), findsOneWidget);

      // Modern location card is present with location details & Change CTA
      expect(find.text('Change'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsWidgets);

      // SOS emergency trigger is prominent
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('TAP FOR HELP'), findsOneWidget);

      // Tapping profile avatar header switches to Profile tab
      await tester.tap(find.textContaining('Welcome,'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('SosScreen circular countdown dial, cancellation, and live GPS precision indicator', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: SosScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Circular progress indicator present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('999'), findsOneWidget);

      // Tap to cancel button is present
      final cancelFinder = find.textContaining('TAP TO CANCEL');
      expect(cancelFinder, findsOneWidget);

      // Tap to cancel
      await tester.tap(cancelFinder);
      await tester.pump();

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Emergency call cancelled.'), findsOneWidget);

      // Live GPS indicator is present
      expect(find.text('LIVE GPS'), findsOneWidget);
      expect(find.text('GPS Estimating'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('FaultDetailsScreen interactive symptom checklist toggles on/off correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: FaultDetailsScreen(
            selectedFault: 'Dead Battery',
            vehicleType: 'SUV',
            licensePlate: 'Dhaka Metro GA-11-2034',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check symptom options are rendered
      final symptomFinder = find.text('Engine completely silent (no crank)');
      expect(symptomFinder, findsOneWidget);

      // Initially no check icons
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap symptom chip to select
      await tester.tap(symptomFinder);
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap symptom chip again to deselect
      await tester.tap(symptomFinder);
      await tester.pump();
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('LoginScreen authenticates with Email & Password, toggles Sign Up roles, and omits OTP', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1100);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mobile OTP'), findsNothing);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      await tester.tap(find.text('Need a new account? Sign Up'));
      await tester.pump();

      expect(find.text('Create Motorist Account'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signup_role_technician')));
      await tester.pump();
      expect(find.text('Create Technician Account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
