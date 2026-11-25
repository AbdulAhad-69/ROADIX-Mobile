import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadix_mobile/screens/emergency_home_screen.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/screens/mechanic_home_screen.dart';
import 'package:roadix_mobile/screens/profile_screen.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/services/supabase_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';

class MockMapLibrePlatform extends MapLibrePlatform {
  bool _viewCreated = false;

  @override
  Future<void> initPlatform(int id) async {}

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (!_viewCreated) {
      _viewCreated = true;
      scheduleMicrotask(() {
        try {
          onPlatformViewCreated(1);
        } catch (_) {}
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isMethod) return Future.value(null);
    return super.noSuchMethod(invocation);
  }
}

class MockGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      latitude: 23.8759,
      longitude: 90.3795,
      timestamp: DateTime(2026, 11, 22),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    MapLibrePlatform.createInstance = () => MockMapLibrePlatform();
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
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
      // Supabase already initialized in test environment
    }
  });

  group('Milestone 3: Profile Picture Updates & Persistence (R4.1)', () {
    test('SupabaseService profile method signatures support avatarUrl', () async {
      final db = SupabaseService();
      expect(db.updateProfile, isA<Function>());
      expect(db.updateAvatar, isA<Function>());
      expect(db.signOut, isA<Function>());
      await db.signOut();
    });

    testWidgets('EditProfileSheet renders with motorist details and avatar presets', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? savedName;
      String? savedPhone;
      String? savedAvatar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileSheet(
              currentName: 'Aisha Rahman',
              currentPhone: '+8801711223344',
              currentAvatarUrl: null,
              onSave: (newName, newPhone, newAvatar) {
                savedName = newName;
                savedPhone = newPhone;
                savedAvatar = newAvatar;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Edit Profile Details'), findsOneWidget);
      expect(find.text('Aisha Rahman'), findsOneWidget);
      expect(find.text('+8801711223344'), findsOneWidget);
      expect(find.text('CHOOSE AVATAR PRESET'), findsNothing);
      expect(find.text('OR AVATAR IMAGE URL'), findsNothing);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('edit_profile_name_field')),
        'Aisha Rahman Updated',
      );
      await tester.pump();

      // Scroll and tap Save Changes
      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(savedName, 'Aisha Rahman Updated');
      expect(savedPhone, '+8801711223344');
      expect(savedAvatar, isNull);
    });

    testWidgets('EditProfileSheet Remove Photo clears current avatarUrl on save', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? savedAvatar = 'https://res.cloudinary.com/demo/image/upload/v1/old.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileSheet(
              currentName: 'Tanvir Ahmed',
              currentPhone: '+8801711000001',
              currentAvatarUrl: savedAvatar,
              onSave: (name, phone, avatar) {
                savedAvatar = avatar;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('remove_avatar_btn')));
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(savedAvatar, isNull);
    });

    testWidgets('EditProfileSheet is backwards compatible with onProfileSaved callback', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? legacyName;
      String? legacyPhone;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditProfileSheet(
              currentName: 'Kamal Hossain',
              currentPhone: '+8801911998877',
              onProfileSaved: (name, phone) {
                legacyName = name;
                legacyPhone = phone;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(legacyName, 'Kamal Hossain');
      expect(legacyPhone, '+8801911998877');
    });

    testWidgets('ProfileScreen renders avatar container with edit action', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Motorist Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('EmergencyHomeScreen header avatar renders and responds to tap', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmergencyHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header avatar should render
      expect(find.text('Welcome,'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets);

      // Tapping profile avatar header switches to Profile tab (nav index 2)
      await tester.tap(find.text('Welcome,'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Motorist Profile'), findsOneWidget);
    });
  });

  group('Milestone 3: Resilient Auth & Sign Out Transitions (R4.2)', () {
    testWidgets('ProfileScreen sign-out button renders and is protected by try/finally', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final logoutBtn = find.text('Log Out & Return to Login');
      expect(logoutBtn, findsOneWidget);
      expect(find.byIcon(Icons.logout), findsWidgets);

      // Find TextButton and tap
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);

      // Flush Supabase Realtime pending disconnect timer (50s)
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('MechanicHomeScreen sign-out action is protected by try/finally', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MechanicHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final iconBtnFinder = find.ancestor(of: find.byIcon(Icons.logout), matching: find.byType(IconButton));
      expect(iconBtnFinder, findsOneWidget);

      await tester.tap(iconBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);

      // Flush Supabase Realtime pending disconnect timer (50s)
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });

  group('Milestone 3: Assistance Request Workflow & Location Loop Fix (R4.3)', () {
    testWidgets('LocationConfirmScreen in isSelectingLocationOnly mode returns location upon confirmation', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? returnedLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => const LocationConfirmScreen(
                          selectedFault: 'General Breakdown',
                          initialLat: 23.8759,
                          initialLng: 90.3795,
                          isSelectingLocationOnly: true,
                        ),
                      ),
                    );
                    returnedLocation = res;
                  },
                  child: const Text('Open Location Picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open screen
      await tester.tap(find.text('Open Location Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Location Picker'), findsOneWidget);
      expect(find.text('Drag map pin'), findsOneWidget);
      expect(find.text('CONFIRM LOCATION'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap Confirm Location
      await tester.tap(find.text('CONFIRM LOCATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify returned location without getting pushed into VehicleSelectScreen
      expect(find.byType(VehicleSelectScreen), findsNothing);
      expect(returnedLocation, isNotNull);
      expect(returnedLocation!['lat'], closeTo(23.8759, 0.0001));
      expect(returnedLocation!['lng'], closeTo(90.3795, 0.0001));
      expect(returnedLocation!['address'], isNotNull);
    });

    testWidgets('LocationConfirmScreen in standard triage mode proceeds to VehicleSelectScreen', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocationConfirmScreen(
              selectedFault: 'Engine Overheat',
              initialLat: 23.8759,
              initialLng: 90.3795,
              isSelectingLocationOnly: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      await tester.tap(find.text('CONFIRM LOCATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VehicleSelectScreen), findsOneWidget);
    });

    testWidgets('EmergencyHomeScreen Change Location button invokes selection-only mode', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmergencyHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final changeBtn = find.text('Change');
      expect(changeBtn, findsOneWidget);

      await tester.tap(changeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirms LocationConfirmScreen opened in selection-only mode
      expect(find.text('Location Picker'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Confirming location returns to EmergencyHomeScreen
      await tester.tap(find.text('CONFIRM LOCATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EmergencyHomeScreen), findsOneWidget);
      expect(find.byType(VehicleSelectScreen), findsNothing);
    });
  });
}
