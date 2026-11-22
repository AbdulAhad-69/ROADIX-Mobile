import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/fault_details_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/screens/sos_screen.dart';
import 'package:roadix_mobile/screens/splash_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/widgets/contact_editor_sheet.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';
import 'package:roadix_mobile/widgets/notifications_bottom_sheet.dart';
import 'package:roadix_mobile/widgets/search_bottom_sheet.dart';
import 'package:roadix_mobile/widgets/vehicle_editor_sheet.dart';
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
        expect(find.text('PRESS FOR HELP'), findsOneWidget);
        expect(find.text('What do you need help with?'), findsOneWidget);
        expect(find.text('Instant triage'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);
        expect(find.text('Flat Tire'), findsOneWidget);
        expect(find.text('Engine'), findsOneWidget);
        expect(find.text('Fuel'), findsOneWidget);
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
      expect(find.text('TECHNICIAN CONSOLE'), findsOneWidget);

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
      expect(find.text('PROPULSION / FUEL TYPE'), findsOneWidget);

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
      expect(find.text('Highway Advisories'), findsOneWidget);

      // 5. SearchBottomSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBottomSheet(
              onFacilitySelected: (name, lat, lng) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Facilities'), findsOneWidget);

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
      expect(find.text('Edit Motorist Details'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
